from typing import Optional
from pydantic import BaseModel


class DeviceCreate(BaseModel):
    name: str
    location: str
    device_id: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class DeviceUpdate(BaseModel):
    name: Optional[str] = None
    location: Optional[str] = None
    status: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class DeviceAutoRegister(BaseModel):
    device_id: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    name: Optional[str] = None


class DeviceResponse(BaseModel):
    id: str
    name: str
    location: str
    device_id: str
    status: str
    user_id: str
    created_at: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
