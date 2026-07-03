"""Phase 5 — Family Protection."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models, schemas
from ..deps import get_current_user

router = APIRouter(prefix="/family", tags=["family"])


def _serialize(link: models.FamilyLink, member: models.User | None) -> dict:
    return {
        "id": link.id,
        "member_id": link.member_id,
        "member_label": link.member_label,
        "member_email": member.email if member else None,
        "alerts_enabled": link.alerts_enabled,
        "min_risk_to_alert": link.min_risk_to_alert,
        "created_at": link.created_at,
    }


@router.get("/members")
def list_family_members(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    links = db.query(models.FamilyLink).filter(models.FamilyLink.guardian_id == user.id).all()
    result = []
    for link in links:
        member = db.query(models.User).filter(models.User.id == link.member_id).first()
        result.append(_serialize(link, member))
    return result


@router.post("/invite")
def invite_family_member(
    req: schemas.FamilyInviteRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    member = db.query(models.User).filter(models.User.email == req.member_email).first()
    if not member:
        raise HTTPException(status_code=404, detail="That email isn't registered on NexusShield yet. They need to create an account first.")
    if member.id == user.id:
        raise HTTPException(status_code=400, detail="You can't add yourself as a family member")

    existing = db.query(models.FamilyLink).filter(
        models.FamilyLink.guardian_id == user.id, models.FamilyLink.member_id == member.id
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="This person is already linked")

    link = models.FamilyLink(
        guardian_id=user.id, member_id=member.id,
        member_label=req.member_label, min_risk_to_alert=req.min_risk_to_alert,
    )
    db.add(link)
    db.commit()
    return _serialize(link, member)


@router.patch("/members/{link_id}/toggle")
def toggle_alerts(link_id: str, user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    link = db.query(models.FamilyLink).filter(
        models.FamilyLink.id == link_id, models.FamilyLink.guardian_id == user.id
    ).first()
    if not link:
        raise HTTPException(status_code=404, detail="Family link not found")
    link.alerts_enabled = not link.alerts_enabled
    db.commit()
    return {"alerts_enabled": link.alerts_enabled}


@router.delete("/members/{link_id}")
def remove_family_member(link_id: str, user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    link = db.query(models.FamilyLink).filter(
        models.FamilyLink.id == link_id, models.FamilyLink.guardian_id == user.id
    ).first()
    if not link:
        raise HTTPException(status_code=404, detail="Family link not found")
    db.delete(link)
    db.commit()
    return {"message": "Removed"}


@router.get("/alerts")
def family_alert_feed(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    """Recent high-risk scans from any family member this guardian watches."""
    links = db.query(models.FamilyLink).filter(
        models.FamilyLink.guardian_id == user.id, models.FamilyLink.alerts_enabled == True  # noqa: E712
    ).all()
    if not links:
        return []

    alerts = []
    for link in links:
        member = db.query(models.User).filter(models.User.id == link.member_id).first()
        scans = db.query(models.ScanHistory).filter(
            models.ScanHistory.user_id == link.member_id,
            models.ScanHistory.risk_score >= link.min_risk_to_alert,
        ).order_by(models.ScanHistory.created_at.desc()).limit(10).all()
        for s in scans:
            alerts.append({
                "member_label": link.member_label,
                "member_email": member.email if member else None,
                "scam_type": s.scam_type,
                "risk_score": s.risk_score,
                "created_at": s.created_at,
            })
    alerts.sort(key=lambda a: a["created_at"], reverse=True)
    return alerts[:30]
