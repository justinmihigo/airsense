"""SMTP email helper. Runs blocking smtplib in a thread to stay async-friendly."""

from __future__ import annotations

import asyncio
import logging
import smtplib
from email.message import EmailMessage
from typing import Iterable

from app.core.config import settings

logger = logging.getLogger(__name__)


LEVEL_COLORS = {
    "info": "#3B82F6",
    "warning": "#F59E0B",
    "critical": "#EF4444",
}


def _build_alert_html(message: str, level: str, device: str, field: str) -> str:
    color = LEVEL_COLORS.get(level, "#6B7280")
    safe = lambda s: (s or "").replace("<", "&lt;").replace(">", "&gt;")
    return f"""
    <div style="font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#F6F6FA;padding:24px;">
      <div style="max-width:560px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;border:1px solid #E5E7EB;">
        <div style="background:{color};padding:16px 20px;color:#fff;">
          <div style="font-size:11px;letter-spacing:.08em;text-transform:uppercase;opacity:.9">AirSense Alert</div>
          <div style="font-size:18px;font-weight:700;margin-top:2px">{safe(level).upper()}</div>
        </div>
        <div style="padding:20px;color:#111827;">
          <p style="margin:0 0 12px 0;font-size:14px;line-height:1.5;">{safe(message)}</p>
          <table style="width:100%;font-size:12px;color:#6B7280;border-collapse:collapse;">
            <tr><td style="padding:4px 0;width:80px">Device</td><td style="color:#111827;">{safe(device) or '—'}</td></tr>
            <tr><td style="padding:4px 0;">Sensor</td><td style="color:#111827;">{safe(field) or '—'}</td></tr>
          </table>
          <a href="{settings.APP_URL}/notifications" style="display:inline-block;margin-top:16px;background:#22C55E;color:#fff;text-decoration:none;padding:10px 16px;border-radius:10px;font-size:13px;font-weight:600;">Open AirSense</a>
        </div>
        <div style="padding:12px 20px;border-top:1px solid #F3F4F6;font-size:11px;color:#9CA3AF;">
          You are receiving this because alert emails are enabled in your AirSense profile.
        </div>
      </div>
    </div>
    """


def _send_sync(to_addrs: list[str], subject: str, html: str, plain: str) -> None:
    if not settings.SMTP_HOST:
        logger.info("SMTP not configured — skipping email to %s", to_addrs)
        return
    msg = EmailMessage()
    msg["From"] = settings.SMTP_FROM
    msg["To"] = ", ".join(to_addrs)
    msg["Subject"] = subject
    msg.set_content(plain)
    msg.add_alternative(html, subtype="html")

    try:
        if settings.SMTP_PORT == 465:
            with smtplib.SMTP_SSL(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as s:
                if settings.SMTP_USERNAME:
                    s.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
                s.send_message(msg)
        else:
            with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as s:
                if settings.SMTP_TLS:
                    s.starttls()
                if settings.SMTP_USERNAME:
                    s.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
                s.send_message(msg)
    except Exception as e:
        logger.warning("SMTP send failed (%s): %s", type(e).__name__, e)


async def send_alert_email(
    to_addrs: Iterable[str],
    *,
    message: str,
    level: str,
    device: str = "",
    field: str = "",
) -> None:
    """Fire-and-forget alert email. Never raises — failures are logged."""
    recipients = [a for a in to_addrs if a]
    if not recipients:
        return
    subject = f"[AirSense · {level.upper()}] {message[:80]}"
    html = _build_alert_html(message, level, device, field)
    plain = f"AirSense {level.upper()}\n\n{message}\n\nDevice: {device or '—'}\nSensor: {field or '—'}\n\n{settings.APP_URL}/notifications"
    await asyncio.to_thread(_send_sync, recipients, subject, html, plain)
