"""Phase 6 — PDF Report download endpoint."""
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models
from ..deps import get_current_user
from ..report_pdf import generate_scan_report_pdf

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/pdf/{history_id}")
def download_scan_pdf(
    history_id: str,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    item = db.query(models.ScanHistory).filter(
        models.ScanHistory.id == history_id, models.ScanHistory.user_id == user.id
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Scan not found")

    filepath = generate_scan_report_pdf(item, user)
    return FileResponse(filepath, media_type="application/pdf", filename=f"NexusShield_Report_{history_id[:8]}.pdf")
