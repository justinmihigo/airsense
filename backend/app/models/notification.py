from typing import Optional
from pydantic import BaseModel


class NotificationCreate(BaseModel):
    message: str
    level: str = "info"  # info | warning | critical
    device: str = ""
    field: str = ""
    user_id: Optional[str] = None   # admin only: target a specific user
    broadcast: bool = False          # admin only: send to all users


class AlertIngest(BaseModel):
    """A sensor-threshold alert raised by the frontend.

    Server-side dedup prevents the same (user, device, field, level) from
    creating more than one notification per cooldown window.
    """
    message: str
    level: str = "warning"            # info | warning | critical
    device: str = ""
    field: str = ""
    value: Optional[float] = None
    threshold: Optional[float] = None


class NotificationPreferences(BaseModel):
    email_alerts: Optional[bool] = None
    web_alerts: Optional[bool] = None
    min_level: Optional[str] = None    # "info" | "warning" | "critical"

