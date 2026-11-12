"""Phase 5 — Admin Panel: users, reports, scam database, analytics.

Default demo admin: admin@nexusshield.app / ChangeMe123! (seeded in seed_data.py).
Change this password immediately in any real deployment.
"""
import datetime as dt

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models, schemas
from ..deps import get_current_admin
from ..scam_db import severity_to_risk_score

router = APIRouter(prefix="/admin", tags=["admin"])


# ── User management ──────────────────────────────────────────────────────────
@router.get("/users")
def list_users(admin: models.User = Depends(get_current_admin), db: DBSession = Depends(get_db)):
    users = db.query(models.User).order_by(models.User.created_at.desc()).all()
    return [
        {
            "id": u.id, "email": u.email, "name": u.name, "is_admin": u.is_admin,
            "is_email_verified": u.is_email_verified, "created_at": u.created_at,
            "last_login_at": u.last_login_at, "organization_id": u.organization_id,
        }
        for u in users
    ]


@router.delete("/users/{user_id}")
def delete_user(user_id: str, admin: models.User = Depends(get_current_admin), db: DBSession = Depends(get_db)):
    if user_id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own admin account from here")
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user)
    db.commit()
    return {"message": "User deleted"}


@router.patch("/users/{user_id}/toggle-admin")
def toggle_admin(user_id: str, admin: models.User = Depends(get_current_admin), db: DBSession = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_admin = not user.is_admin
    db.commit()
    return {"is_admin": user.is_admin}


# ── Report review ─────────────────────────────────────────────────────────────
@router.get("/reports")
def list_reports(
    status: str | None = None,
    admin: models.User = Depends(get_current_admin),
    db: DBSession = Depends(get_db),
):
    query = db.query(models.ScamReport)
    if status:
        query = query.filter(models.ScamReport.status == status)
    reports = query.order_by(models.ScamReport.created_at.desc()).all()
    return [
        {
            "id": r.id, "reporter_id": r.reporter_id, "website": r.website,
            "phone_number": r.phone_number, "upi_id": r.upi_id, "description": r.description,
            "category": r.category, "status": r.status, "admin_notes": r.admin_notes,
            "created_at": r.created_at, "reviewed_at": r.reviewed_at,
        }
        for r in reports
    ]


@router.patch("/reports/{report_id}/review")
def review_report(
    report_id: str,
    req: schemas.ReportReviewRequest,
    admin: models.User = Depends(get_current_admin),
    db: DBSession = Depends(get_db),
):
    report = db.query(models.ScamReport).filter(models.ScamReport.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    if req.status not in ("verified", "rejected"):
        raise HTTPException(status_code=400, detail="Status must be 'verified' or 'rejected'")

    report.status = req.status
    report.admin_notes = req.admin_notes
    report.reviewed_by = admin.id
    report.reviewed_at = dt.datetime.utcnow()
    db.commit()

    # If verified, automatically promote indicators into the live scam database.
    if req.status == "verified":
        if report.website:
            db.add(models.ScamDatabaseEntry(
                entry_type="domain", value=report.website, category=report.category,
                severity="high", source="report", notes=f"Promoted from user report {report.id}",
            ))
        if report.phone_number:
            db.add(models.ScamDatabaseEntry(
                entry_type="phone", value=report.phone_number, category=report.category,
                severity="high", source="report", notes=f"Promoted from user report {report.id}",
            ))
        if report.upi_id:
            db.add(models.ScamDatabaseEntry(
                entry_type="upi", value=report.upi_id, category=report.category,
                severity="high", source="report", notes=f"Promoted from user report {report.id}",
            ))
        db.commit()

    return {"message": f"Report {req.status}"}


# ── Scam database management ─────────────────────────────────────────────────
@router.get("/scam-database")
def list_scam_db(admin: models.User = Depends(get_current_admin), db: DBSession = Depends(get_db)):
    entries = db.query(models.ScamDatabaseEntry).order_by(models.ScamDatabaseEntry.added_at.desc()).all()
    return [
        {
            "id": e.id, "entry_type": e.entry_type, "value": e.value, "category": e.category,
            "severity": e.severity, "source": e.source, "notes": e.notes, "added_at": e.added_at,
        }
        for e in entries
    ]


@router.post("/scam-database")
def add_scam_db_entry(
    req: schemas.ScamDbEntryRequest,
    admin: models.User = Depends(get_current_admin),
    db: DBSession = Depends(get_db),
):
    if req.entry_type not in ("url", "domain", "phone", "upi"):
        raise HTTPException(status_code=400, detail="entry_type must be one of: url, domain, phone, upi")
    entry = models.ScamDatabaseEntry(
        entry_type=req.entry_type, value=req.value, category=req.category,
        severity=req.severity, notes=req.notes, source="admin",
    )
    db.add(entry)
    db.commit()
    return {"id": entry.id, "implied_risk_score": severity_to_risk_score(entry.severity)}


@router.delete("/scam-database/{entry_id}")
def delete_scam_db_entry(entry_id: str, admin: models.User = Depends(get_current_admin), db: DBSession = Depends(get_db)):
    entry = db.query(models.ScamDatabaseEntry).filter(models.ScamDatabaseEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    db.delete(entry)
    db.commit()
    return {"message": "Deleted"}


# ── Platform-wide analytics ──────────────────────────────────────────────────
@router.get("/analytics")
def platform_analytics(admin: models.User = Depends(get_current_admin), db: DBSession = Depends(get_db)):
    total_users = db.query(models.User).count()
    total_scans = db.query(models.ScanHistory).count()
    high_risk_scans = db.query(models.ScanHistory).filter(models.ScanHistory.risk_score >= 70).count()
    pending_reports = db.query(models.ScamReport).filter(models.ScamReport.status == "pending").count()
    scam_db_size = db.query(models.ScamDatabaseEntry).count()

    by_category: dict[str, int] = {}
    for s in db.query(models.ScanHistory).all():
        by_category[s.category] = by_category.get(s.category, 0) + 1

    return {
        "total_users": total_users,
        "total_scans": total_scans,
        "high_risk_scans": high_risk_scans,
        "pending_reports": pending_reports,
        "scam_database_size": scam_db_size,
        "scans_by_category": [{"category": k, "count": v} for k, v in by_category.items()],
    }
