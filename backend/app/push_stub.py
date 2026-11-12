"""
Push notification dispatch — INTEGRATION STUB.

This is the single place a real push backend (Firebase Cloud Messaging for
Android, APNs for iOS) would be wired in. Right now it only writes a row to
the `notifications` table (so the in-app notification center always works),
and logs what *would* have been sent.

To go live:
1. `pip install firebase-admin` and add a service-account JSON via
   FCM_SERVICE_ACCOUNT_PATH env var.
2. Store each user's FCM device token (add a `fcm_token` column on User,
   collected client-side after Firebase init in the Flutter app).
3. Replace the `print(...)` below with `messaging.send(...)`.
"""
import logging
from sqlalchemy.orm import Session as DBSession

from . import models

logger = logging.getLogger("nexusshield.push")


def send_notification(db: DBSession, user_id: str, title: str, body: str, kind: str = "alert"):
    notification = models.Notification(user_id=user_id, title=title, body=body, kind=kind)
    db.add(notification)
    db.commit()

    # INTEGRATION POINT: replace with real FCM/APNs call once configured.
    logger.info("PUSH (stub) -> user=%s title=%r body=%r", user_id, title, body)
    return notification


def broadcast_threat_alert(db: DBSession, title: str, body: str):
    """Send a threat-feed alert to every user who has alerts enabled."""
    users = db.query(models.User).filter(models.User.notif_threat_alerts == True).all()  # noqa: E712
    for u in users:
        send_notification(db, u.id, title, body, kind="alert")
