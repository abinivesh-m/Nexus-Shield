"""Phase 2 — User Profile."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models, schemas
from ..deps import get_current_user

router = APIRouter(prefix="/profile", tags=["profile"])


def _serialize(user: models.User) -> dict:
    return {
        "id": user.id,
        "email": user.email,
        "name": user.name,
        "photo_url": user.photo_url,
        "auth_provider": user.auth_provider,
        "is_email_verified": user.is_email_verified,
        "is_admin": user.is_admin,
        "language": user.language,
        "theme": user.theme,
        "notification_settings": {
            "push_enabled": user.notif_push_enabled,
            "threat_alerts": user.notif_threat_alerts,
            "weekly_summary": user.notif_weekly_summary,
        },
        "security_settings": {
            "biometric_lock": user.security_biometric_lock,
            "auto_scan_clipboard": user.security_auto_scan_clipboard,
        },
        "organization_id": user.organization_id,
        "created_at": user.created_at,
    }


@router.get("/me")
def get_profile(user: models.User = Depends(get_current_user)):
    return _serialize(user)


@router.patch("/me")
def update_profile(
    req: schemas.ProfileUpdateRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    data = req.model_dump(exclude_unset=True)
    field_map = {
        "name": "name", "photo_url": "photo_url", "language": "language", "theme": "theme",
        "notif_push_enabled": "notif_push_enabled",
        "notif_threat_alerts": "notif_threat_alerts",
        "notif_weekly_summary": "notif_weekly_summary",
        "security_biometric_lock": "security_biometric_lock",
        "security_auto_scan_clipboard": "security_auto_scan_clipboard",
    }
    for key, attr in field_map.items():
        if key in data and data[key] is not None:
            setattr(user, attr, data[key])
    db.commit()
    return _serialize(user)


@router.delete("/me")
def delete_account(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    db.delete(user)
    db.commit()
    return {"message": "Account deleted"}
