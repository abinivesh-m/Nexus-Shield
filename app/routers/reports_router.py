"""Phase 1 — Scam Reporting (user submission side). Admin review lives in admin_router.py."""
import base64
import os
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models, schemas
from ..deps import get_current_user

router = APIRouter(prefix="/reports", tags=["reports"])

UPLOAD_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "report_screenshots"
)
os.makedirs(UPLOAD_DIR, exist_ok=True)


def _serialize(r: models.ScamReport) -> dict:
    return {
        "id": r.id,
        "reporter_id": r.reporter_id,
        "screenshot_path": r.screenshot_path,
        "website": r.website,
        "phone_number": r.phone_number,
        "upi_id": r.upi_id,
        "description": r.description,
        "category": r.category,
        "status": r.status,
        "admin_notes": r.admin_notes,
        "created_at": r.created_at,
        "reviewed_at": r.reviewed_at,
    }


@router.post("")
def submit_report(
    req: schemas.ScamReportRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    if not any([req.website, req.phone_number, req.upi_id, req.description, req.screenshot_base64]):
        raise HTTPException(status_code=400, detail="Provide at least one of: screenshot, website, phone number, UPI ID, or description")

    screenshot_path = ""
    if req.screenshot_base64:
        filename = f"{uuid.uuid4().hex}.jpg"
        full_path = os.path.join(UPLOAD_DIR, filename)
        with open(full_path, "wb") as f:
            f.write(base64.b64decode(req.screenshot_base64))
        screenshot_path = full_path

    report = models.ScamReport(
        reporter_id=user.id,
        screenshot_path=screenshot_path,
        website=req.website,
        phone_number=req.phone_number,
        upi_id=req.upi_id,
        description=req.description,
        category=req.category,
    )
    db.add(report)
    db.commit()
    return _serialize(report)


@router.get("/mine")
def my_reports(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    reports = db.query(models.ScamReport).filter(
        models.ScamReport.reporter_id == user.id
    ).order_by(models.ScamReport.created_at.desc()).all()
    return [_serialize(r) for r in reports]


@router.delete("/{report_id}")
def delete_my_report(report_id: str, user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    report = db.query(models.ScamReport).filter(
        models.ScamReport.id == report_id, models.ScamReport.reporter_id == user.id
    ).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    if report.status != "pending":
        raise HTTPException(status_code=400, detail="Cannot delete a report that has already been reviewed")
    db.delete(report)
    db.commit()
    return {"message": "Report deleted"}
