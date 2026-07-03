"""Phase 5 — Enterprise/Organization features."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession
from sqlalchemy import func

from ..database import get_db
from .. import models, schemas
from ..deps import get_current_user

router = APIRouter(prefix="/org", tags=["organization"])


def _require_org_admin(user: models.User, db: DBSession) -> models.Organization:
    if not user.organization_id:
        raise HTTPException(status_code=403, detail="You are not part of an organization")
    org = db.query(models.Organization).filter(models.Organization.id == user.organization_id).first()
    if not org:
        raise HTTPException(status_code=404, detail="Organization not found")
    return org


@router.post("/create")
def create_organization(
    req: schemas.OrgCreateRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    if user.organization_id:
        raise HTTPException(status_code=400, detail="You already belong to an organization")
    org = models.Organization(name=req.name)
    db.add(org)
    db.commit()
    user.organization_id = org.id
    db.commit()
    return {"id": org.id, "name": org.name, "plan": org.plan}


@router.post("/invite")
def invite_to_org(
    req: schemas.OrgInviteRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    org = _require_org_admin(user, db)
    member = db.query(models.User).filter(models.User.email == req.email).first()
    if not member:
        raise HTTPException(status_code=404, detail="That email isn't registered yet")
    if member.organization_id:
        raise HTTPException(status_code=400, detail="That user already belongs to an organization")
    member.organization_id = org.id
    db.commit()
    return {"message": f"{member.email} added to {org.name}"}


@router.get("/members")
def list_org_members(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    _require_org_admin(user, db)
    members = db.query(models.User).filter(models.User.organization_id == user.organization_id).all()
    return [
        {"id": m.id, "email": m.email, "name": m.name, "last_login_at": m.last_login_at}
        for m in members
    ]


@router.get("/dashboard")
def org_dashboard(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    """Aggregate scan trends across the whole organization."""
    _require_org_admin(user, db)
    member_ids = [
        m.id for m in db.query(models.User).filter(models.User.organization_id == user.organization_id).all()
    ]
    if not member_ids:
        return {"total_scans": 0, "high_risk_count": 0, "by_category": [], "by_member": []}

    scans = db.query(models.ScanHistory).filter(models.ScanHistory.user_id.in_(member_ids)).all()
    total_scans = len(scans)
    high_risk_count = sum(1 for s in scans if s.risk_score >= 70)

    by_category: dict[str, int] = {}
    for s in scans:
        by_category[s.category] = by_category.get(s.category, 0) + 1

    by_member: dict[str, dict] = {}
    for s in scans:
        by_member.setdefault(s.user_id, {"scans": 0, "high_risk": 0})
        by_member[s.user_id]["scans"] += 1
        if s.risk_score >= 70:
            by_member[s.user_id]["high_risk"] += 1

    member_lookup = {m.id: m for m in db.query(models.User).filter(models.User.id.in_(member_ids)).all()}
    by_member_list = [
        {"email": member_lookup[uid].email, "name": member_lookup[uid].name, **stats}
        for uid, stats in by_member.items() if uid in member_lookup
    ]

    return {
        "total_scans": total_scans,
        "high_risk_count": high_risk_count,
        "by_category": [{"category": k, "count": v} for k, v in by_category.items()],
        "by_member": by_member_list,
    }


@router.get("/export")
def export_org_report(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    """JSON export suitable for converting into a PDF org report (see /reports/pdf)."""
    return org_dashboard(user, db)
