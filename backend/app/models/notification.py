from typing import Optional
from pydantic import BaseModel


class NotificationCreate(BaseModel):
    message: str
    level: str = "info"  # info | warning | critical
    device: str = ""
    field: str = ""
    user_id: Optional[str] = None   # admin only: target a specific user
    broadcast: bool = False          # admin only: send to all users
