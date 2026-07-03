"""
Phase 9 — Notifications.

Stores notifications server-side and exposes them via polling. Actual push
delivery (FCM/APNs) needs real project credentials — `push_stub.py` shows
where that call would go; until then notifications are visible in-app via
this endpoint, which still gives full alert functionality without a push
backend.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models
from ..deps import get_current_user

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _serialize(n: models.Notification) -> dict:
    return {
        "id": n.id, "title": n.title, "body": n.body, "kind": n.kind,
        "is_read": n.is_read, "created_at": n.created_at,
    }


@router.get("")
def list_notifications(
    unread_only: bool = False,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    query = db.query(models.Notification).filter(models.Notification.user_id == user.id)
    if unread_only:
        query = query.filter(models.Notification.is_read == False)  # noqa: E712
    items = query.order_by(models.Notification.created_at.desc()).limit(100).all()
    return [_serialize(n) for n in items]


@router.patch("/{notification_id}/read")
def mark_read(notification_id: str, user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    n = db.query(models.Notification).filter(
        models.Notification.id == notification_id, models.Notification.user_id == user.id
    ).first()
    if not n:
        raise HTTPException(status_code=404, detail="Notification not found")
    n.is_read = True
    db.commit()
    return {"message": "Marked as read"}


@router.patch("/read-all")
def mark_all_read(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    db.query(models.Notification).filter(
        models.Notification.user_id == user.id, models.Notification.is_read == False  # noqa: E712
    ).update({"is_read": True})
    db.commit()
    return {"message": "All marked as read"}
