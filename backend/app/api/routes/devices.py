from datetime import datetime, timezone
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException
from motor.motor_asyncio import AsyncIOMotorDatabase
from app.api.deps import get_current_user, get_admin_user
from app.db.mongodb import get_database
from app.models.device import DeviceCreate, DeviceUpdate, DeviceAutoRegister

router = APIRouter()


def _serialize(device: dict) -> dict:
    return {
        "id": str(device["_id"]),
        "name": device["name"],
        "location": device["location"],
        "device_id": device["device_id"],
        "status": device.get("status", "active"),
        "user_id": str(device["user_id"]),
        "created_at": device["created_at"].isoformat(),
        "latitude": device.get("latitude"),
        "longitude": device.get("longitude"),
    }


@router.get("")
async def list_devices(
    current_user: dict = Depends(get_current_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    query = {} if current_user.get("role") == "admin" else {"user_id": current_user["_id"]}
    cursor = db.devices.find(query)
    return [_serialize(d) async for d in cursor]


@router.post("")
async def create_device(
    body: DeviceCreate,
    admin: dict = Depends(get_admin_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    doc = {
        **body.model_dump(),
        "user_id": admin["_id"],
        "status": "active",
        "created_at": datetime.now(timezone.utc),
    }
    result = await db.devices.insert_one(doc)
    doc["_id"] = result.inserted_id
    return _serialize(doc)


@router.post("/auto-register")
async def auto_register_device(
    body: DeviceAutoRegister,
    current_user: dict = Depends(get_current_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    now = datetime.now(timezone.utc)
    result = await db.devices.find_one_and_update(
        {"device_id": body.device_id},
        {
            "$setOnInsert": {
                "user_id": current_user["_id"],
                "created_at": now,
                "status": "active",
                "name": body.name or body.device_id,
                "location": "Auto-registered",
            },
            "$set": {
                k: v
                for k, v in {"latitude": body.latitude, "longitude": body.longitude}.items()
                if v is not None
            },
        },
        upsert=True,
        return_document=True,
    )
    return _serialize(result)


@router.patch("/{device_id}")
async def update_device(
    device_id: str,
    body: DeviceUpdate,
    current_user: dict = Depends(get_current_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    device = await db.devices.find_one({"_id": ObjectId(device_id), "user_id": current_user["_id"]})
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    updates = body.model_dump(exclude_none=True)
    if updates:
        await db.devices.update_one({"_id": ObjectId(device_id)}, {"$set": updates})
    updated = await db.devices.find_one({"_id": ObjectId(device_id)})
    return _serialize(updated)


@router.delete("/{device_id}", status_code=204)
async def delete_device(
    device_id: str,
    _: dict = Depends(get_admin_user),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    result = await db.devices.delete_one({"_id": ObjectId(device_id)})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Device not found")
