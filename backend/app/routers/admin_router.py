"""Phase 5 — Admin Panel: users, reports, scam database, analytics.

Default demo admin: admin@nexusshield.app / ChangeMe123! (seeded in seed_data.py).
Change this password immediately in any real deployment.
"""
import datetime as dt

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models, schemas
from .. import receipts as receipts_mod
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


# ── Internship pilot accuracy ────────────────────────────────────────────────
def _verdict_bucket(verdict: str) -> str:
    """Collapse free-text verdicts into the two decisions we can score."""
    text = (verdict or "").lower()
    if "scam" in text:
        return "scam"
    if "genuine" in text or "safe" in text:
        return "genuine"
    return "other"


@router.get("/internship/feedback")
def internship_feedback_summary(
    admin: models.User = Depends(get_current_admin),
    db: DBSession = Depends(get_db),
):
    """Precision / recall of the internship verifier on real offers.

    A "positive" is a scam verdict. Precision answers "when we said scam, how
    often were we right?" - the number that decides whether a student can
    trust the tool. Recall answers "of the real scams, how many did we catch?"
    """
    rows = (
        db.query(models.InternshipFeedback)
        .order_by(models.InternshipFeedback.created_at.desc())
        .all()
    )

    tp = fp = fn = tn = 0
    disagreements = []
    for row in rows:
        predicted = _verdict_bucket(row.predicted_verdict)
        actual = _verdict_bucket(row.actual_verdict)
        if predicted == "scam" and actual == "scam":
            tp += 1
        elif predicted == "scam" and actual == "genuine":
            fp += 1
        elif predicted == "genuine" and actual == "scam":
            fn += 1
        elif predicted == "genuine" and actual == "genuine":
            tn += 1

        if predicted in ("scam", "genuine") and actual in ("scam", "genuine") \
                and predicted != actual:
            disagreements.append({
                "id": row.id,
                "predicted_verdict": row.predicted_verdict,
                "predicted_score": row.predicted_score,
                "actual_verdict": row.actual_verdict,
                "reason": row.reason,
                "notes": row.notes,
                "offer_hash": row.offer_hash,
                "created_at": row.created_at,
            })

    def _ratio(num: int, den: int):
        return round(num / den, 4) if den else None

    scored = tp + fp + fn + tn
    return {
        "total_feedback": len(rows),
        "scored": scored,
        "confusion": {
            "true_positive": tp,
            "false_positive": fp,
            "false_negative": fn,
            "true_negative": tn,
        },
        "precision": _ratio(tp, tp + fp),
        "recall": _ratio(tp, tp + fn),
        "false_positive_rate": _ratio(fp, fp + tn),
        "accuracy": _ratio(tp + tn, scored),
        "disagreements": disagreements[:100],
    }


# ── Verified offer receipts ──────────────────────────────────────────────────
@router.get("/receipts")
def list_receipts(
    revoked: bool | None = None,
    admin: models.User = Depends(get_current_admin),
    db: DBSession = Depends(get_db),
):
    query = db.query(models.OfferReceipt)
    if revoked is not None:
        query = query.filter(models.OfferReceipt.revoked == revoked)
    rows = query.order_by(models.OfferReceipt.issued_at.desc()).limit(200).all()
    return [
        {
            "id": r.id,
            "verdict": r.verdict,
            "risk_score": r.risk_score,
            "employer_domain": r.employer_domain,
            "company_verified": r.company_verified,
            "offer_hash": r.offer_hash,
            "issued_at": r.issued_at,
            "revoked": r.revoked,
            "revoked_reason": r.revoked_reason,
        }
        for r in rows
    ]


@router.post("/receipts/revoke")
def revoke_receipts(
    req: schemas.ReceiptRevokeRequest,
    admin: models.User = Depends(get_current_admin),
    db: DBSession = Depends(get_db),
):
    """Retroactively invalidate receipts.

    Revoking by `offer_hash` is the important case: one confirmed scam
    invalidates every receipt ever issued for that same offer, including
    ones already sitting in students' chats.
    """
    if not req.receipt_id and not req.offer_hash:
        raise HTTPException(status_code=400, detail="Provide receipt_id or offer_hash")

    query = db.query(models.OfferReceipt)
    if req.receipt_id:
        query = query.filter(models.OfferReceipt.id == req.receipt_id)
    else:
        query = query.filter(models.OfferReceipt.offer_hash == req.offer_hash)

    rows = query.all()
    if not rows:
        raise HTTPException(status_code=404, detail="No matching receipt")

    stamp = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)
    for row in rows:
        row.revoked = True
        row.revoked_reason = (req.reason or "Revoked by administrator")[:240]
        row.revoked_at = stamp
    db.commit()

    return {"revoked": len(rows), "reason": rows[0].revoked_reason}


@router.post("/receipts/resign")
def resign_receipts(
    admin: models.User = Depends(get_current_admin),
    db: DBSession = Depends(get_db),
):
    """One-time maintenance: re-sign every receipt with the current secret.

    Needed after rotating RECEIPT_SECRET so that existing rows keep a valid
    signature. Remove this endpoint once the migration has run.
    """
    rows = db.query(models.OfferReceipt).all()
    for row in rows:
        payload = receipts_mod.build_payload(
            row.id, row.issued_at, row.verdict, row.risk_score,
            row.employer_domain, row.company_verified, row.offer_hash,
        )
        row.signature = receipts_mod.sign(payload)
    db.commit()
    return {"resigned": len(rows)}


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
