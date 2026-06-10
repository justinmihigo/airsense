from datetime import datetime, timedelta, timezone
from bson import ObjectId
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.api.deps import get_current_user, get_admin_user
from app.core.config import settings
from app.db.mongodb import get_database
from app.models.notification import (
    AlertIngest,
    NotificationCreate,
    NotificationPreferences,
)
from app.services.email import send_alert_email

router = APIRouter()

LEVEL_RANK = {"info": 0, "warning": 1, "critical": 2}


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


def _prefs(user: dict) -> dict:
    p = user.get("notification_prefs") or {}
    return {
        "email_alerts": bool(p.get("email_alerts", True)),
        "web_alerts": bool(p.get("web_alerts", True)),
        "min_level": p.get("min_level", "warning"),
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


@router.get("/preferences")
async def get_preferences(current_user: dict = Depends(get_current_user)):
    return _prefs(current_user)


@router.patch("/preferences")
async def update_preferences(
    body: NotificationPreferences,
    current_user: dict = Depends(get_current_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    current = _prefs(current_user)
    updates = body.model_dump(exclude_none=True)
    if updates.get("min_level") and updates["min_level"] not in LEVEL_RANK:
        raise HTTPException(status_code=422, detail="min_level must be info|warning|critical")
    merged = {**current, **updates}
    await db.users.update_one(
        {"_id": current_user["_id"]},
        {"$set": {"notification_prefs": merged}},
    )
    return merged


@router.post("/alerts", status_code=201)
async def ingest_alert(
    body: AlertIngest,
    background: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Record a sensor-threshold alert for the current user.

    Enforces a cooldown (default 10 min) per (user, device, field, level) so
    repeated readings don't spam the user. If the same alert was already raised
    within the window, returns the existing notification with `throttled=true`
    and no email is sent.
    """
    prefs = _prefs(current_user)

    if LEVEL_RANK.get(body.level, 0) < LEVEL_RANK.get(prefs["min_level"], 1):
        return {"throttled": True, "reason": "below_min_level", "min_level": prefs["min_level"]}

    cutoff = datetime.now(timezone.utc) - timedelta(minutes=settings.ALERT_COOLDOWN_MINUTES)
    existing = await db.notifications.find_one(
        {
            "user_id": current_user["_id"],
            "device": body.device,
            "field": body.field,
            "level": body.level,
            "created_at": {"$gte": cutoff},
        },
        sort=[("created_at", -1)],
    )
    if existing:
        retry_after = int(
            (existing["created_at"] + timedelta(minutes=settings.ALERT_COOLDOWN_MINUTES)
             - datetime.now(timezone.utc)).total_seconds()
        )
        return {
            "throttled": True,
            "reason": "cooldown",
            "cooldown_minutes": settings.ALERT_COOLDOWN_MINUTES,
            "retry_after_seconds": max(retry_after, 0),
            "notification": _serialize(existing),
        }

    doc = {
        "user_id": current_user["_id"],
        "message": body.message,
        "level": body.level,
        "device": body.device,
        "field": body.field,
        "value": body.value,
        "threshold": body.threshold,
        "read": False,
        "created_at": datetime.now(timezone.utc),
        "source": "sensor",
    }
    result = await db.notifications.insert_one(doc)
    doc["_id"] = result.inserted_id

    if prefs["email_alerts"] and current_user.get("email"):
        background.add_task(
            send_alert_email,
            [current_user["email"]],
            message=body.message,
            level=body.level,
            device=body.device,
            field=body.field,
        )

    return {"throttled": False, "notification": _serialize(doc)}


@router.post("", status_code=201)
async def create_notification(
    body: NotificationCreate,
    background: BackgroundTasks,
    admin: dict = Depends(get_admin_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Admin-only: push a notification to a specific user or broadcast to all users.

    Emails recipients whose preferences allow it (broadcasts include all users).
    """
    base_doc = {
        "message": body.message,
        "level": body.level,
        "device": body.device,
        "field": body.field,
        "read": False,
        "created_at": datetime.now(timezone.utc),
        "source": "broadcast" if body.broadcast else "admin",
    }

    if body.broadcast:
        targets = await db.users.find(
            {}, {"_id": 1, "email": 1, "notification_prefs": 1}
        ).to_list(length=None)
        docs = [{**base_doc, "user_id": u["_id"]} for u in targets]
        if docs:
            await db.notifications.insert_many(docs)

        recipients = [
            u["email"] for u in targets
            if u.get("email") and _prefs(u)["email_alerts"]
            and LEVEL_RANK.get(body.level, 0) >= LEVEL_RANK.get(_prefs(u)["min_level"], 1)
        ]
        if recipients:
            background.add_task(
                send_alert_email,
                recipients,
                message=body.message,
                level=body.level,
                device=body.device,
                field=body.field,
            )
        return {"created": len(docs), "broadcast": True, "emailed": len(recipients)}

    if body.user_id:
        target = await db.users.find_one({"_id": ObjectId(body.user_id)})
        if not target:
            raise HTTPException(status_code=404, detail="Target user not found")
    else:
        target = admin

    doc = {**base_doc, "user_id": target["_id"]}
    result = await db.notifications.insert_one(doc)
    doc["_id"] = result.inserted_id

    target_prefs = _prefs(target)
    if target.get("email") and target_prefs["email_alerts"] \
            and LEVEL_RANK.get(body.level, 0) >= LEVEL_RANK.get(target_prefs["min_level"], 1):
        background.add_task(
            send_alert_email,
            [target["email"]],
            message=body.message,
            level=body.level,
            device=body.device,
            field=body.field,
        )
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
