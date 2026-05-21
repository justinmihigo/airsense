from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException
from motor.motor_asyncio import AsyncIOMotorDatabase
from app.api.deps import get_current_user
from app.db.mongodb import get_database
from app.models.user import UserUpdate

router = APIRouter()


def _serialize(user: dict) -> dict:
    return {
        "id": str(user["_id"]),
        "name": user["name"],
        "email": user["email"],
        "role": user.get("role", "user"),
        "created_at": user["created_at"].isoformat(),
        "email_verified_at": (
            user["email_verified_at"].isoformat() if user.get("email_verified_at") else None
        ),
    }


@router.patch("/me")
async def update_me(
    body: UserUpdate,
    current_user: dict = Depends(get_current_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    updates = body.model_dump(exclude_none=True)
    if not updates:
        return _serialize(current_user)
    if "email" in updates and updates["email"] != current_user["email"]:
        if await db.users.find_one({"email": updates["email"]}):
            raise HTTPException(status_code=400, detail="Email already in use")
    await db.users.update_one({"_id": current_user["_id"]}, {"$set": updates})
    updated = await db.users.find_one({"_id": current_user["_id"]})
    return _serialize(updated)
