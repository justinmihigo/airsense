from datetime import datetime, timezone
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Query
from motor.motor_asyncio import AsyncIOMotorDatabase
from app.api.deps import get_current_user, get_admin_user
from app.db.mongodb import get_database
from app.models.notification import NotificationCreate

router = APIRouter()


def _serialize(n: dict) -> dict:
    return {
        "id": str(n["_id"]),
        "message": n["message"],
        "level": n.get("level", "info"),
        "device": n.get("device", ""),
        "field": n.get("field", ""),
        "read": n.get("read", False),
        "created_at": n["created_at"].isoformat(),
    }


@router.get("")
async def list_notifications(
    limit: int = Query(50, le=200),
    current_user: dict = Depends(get_current_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    cursor = db.notifications.find(
        {"user_id": current_user["_id"]}
    ).sort("created_at", -1).limit(limit)
    return [_serialize(n) async for n in cursor]


@router.post("", status_code=201)
async def create_notification(
    body: NotificationCreate,
    admin: dict = Depends(get_admin_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Admin-only: push a notification to a specific user or broadcast to all users."""
    base_doc = {
        "message": body.message,
        "level": body.level,
        "device": body.device,
        "field": body.field,
        "read": False,
        "created_at": datetime.now(timezone.utc),
    }

    if body.broadcast:
        user_ids = [u["_id"] async for u in db.users.find({}, {"_id": 1})]
        docs = [{**base_doc, "user_id": uid} for uid in user_ids]
        if docs:
            await db.notifications.insert_many(docs)
        return {"created": len(docs), "broadcast": True}

    if body.user_id:
        target = await db.users.find_one({"_id": ObjectId(body.user_id)})
        if not target:
            raise HTTPException(status_code=404, detail="Target user not found")
        target_id = target["_id"]
    else:
        target_id = admin["_id"]

    doc = {**base_doc, "user_id": target_id}
    result = await db.notifications.insert_one(doc)
    doc["_id"] = result.inserted_id
    return _serialize(doc)


@router.patch("/{notification_id}/read")
async def mark_read(
    notification_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    await db.notifications.update_one(
        {"_id": ObjectId(notification_id), "user_id": current_user["_id"]},
        {"$set": {"read": True}},
    )
    return {"ok": True}
