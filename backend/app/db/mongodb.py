from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from app.core.config import settings


class _MongoDB:
    client: AsyncIOMotorClient | None = None


_db = _MongoDB()


async def connect_db() -> None:
    _db.client = AsyncIOMotorClient(settings.MONGODB_URL)


async def close_db() -> None:
    if _db.client:
        _db.client.close()


def get_database() -> AsyncIOMotorDatabase:
    if not _db.client:
        raise RuntimeError("Database not connected")
    return _db.client[settings.DATABASE_NAME]
