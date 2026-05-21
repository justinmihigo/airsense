from datetime import datetime, timezone
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException
from motor.motor_asyncio import AsyncIOMotorDatabase
from app.api.deps import get_current_user
from app.core.security import create_access_token, get_password_hash, verify_password
from app.db.mongodb import get_database
from app.models.user import UserCreate, UserLogin

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


@router.post("/register")
async def register(body: UserCreate, db: AsyncIOMotorDatabase = Depends(get_database)):
    if await db.users.find_one({"email": body.email}):
        raise HTTPException(status_code=400, detail="Email already registered")
    doc = {
        "name": body.name,
        "email": body.email,
        "password_hash": get_password_hash(body.password),
        "role": "user",
        "created_at": datetime.now(timezone.utc),
        "email_verified_at": None,
    }
    result = await db.users.insert_one(doc)
    doc["_id"] = result.inserted_id
    token = create_access_token({"sub": str(result.inserted_id)})
    return {"access_token": token, "token_type": "bearer", "user": _serialize(doc)}


@router.post("/login")
async def login(body: UserLogin, db: AsyncIOMotorDatabase = Depends(get_database)):
    user = await db.users.find_one({"email": body.email})
    if not user or not verify_password(body.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_access_token({"sub": str(user["_id"])})
    return {"access_token": token, "token_type": "bearer", "user": _serialize(user)}


@router.get("/me")
async def me(current_user: dict = Depends(get_current_user)):
    return _serialize(current_user)
