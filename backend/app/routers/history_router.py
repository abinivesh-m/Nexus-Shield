"""Phase 1 — Analysis History: search, delete, export."""
import csv
import io
import datetime as dt

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session as DBSession
from sqlalchemy import or_

from ..database import get_db
from .. import models
from ..deps import get_current_user

router = APIRouter(prefix="/history", tags=["history"])


def _serialize(h: models.ScanHistory) -> dict:
    return {
        "id": h.id,
        "scan_type": h.scan_type,
        "input_preview": h.input_preview,
        "risk_score": h.risk_score,
        "scam_type": h.scam_type,
        "category": h.category,
        "summary": h.summary,
        "red_flags": h.red_flags,
        "advice": h.advice,
        "matched_known_scam": h.matched_known_scam,
        "language": h.language,
        "created_at": h.created_at,
    }


@router.get("")
def list_history(
    q: str | None = Query(default=None, description="Search text across preview/summary/scam_type"),
    scan_type: str | None = None,
    category: str | None = None,
    min_risk: int | None = None,
    limit: int = 50,
    offset: int = 0,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    query = db.query(models.ScanHistory).filter(models.ScanHistory.user_id == user.id)

    if q:
        like = f"%{q}%"
        query = query.filter(or_(
            models.ScanHistory.input_preview.ilike(like),
            models.ScanHistory.summary.ilike(like),
            models.ScanHistory.scam_type.ilike(like),
        ))
    if scan_type:
        query = query.filter(models.ScanHistory.scan_type == scan_type)
    if category:
        query = query.filter(models.ScanHistory.category == category)
    if min_risk is not None:
        query = query.filter(models.ScanHistory.risk_score >= min_risk)

    total = query.count()
    items = query.order_by(models.ScanHistory.created_at.desc()).offset(offset).limit(limit).all()
    return {"total": total, "items": [_serialize(h) for h in items]}


@router.get("/grouped")
def list_history_grouped(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    """Returns history grouped into Today / Yesterday / This Week / Earlier buckets,
    matching the roadmap's 'Yesterday / 2 days ago / Last Week' style UI."""
    items = db.query(models.ScanHistory).filter(
        models.ScanHistory.user_id == user.id
    ).order_by(models.ScanHistory.created_at.desc()).limit(200).all()

    now = dt.datetime.utcnow()
    today = now.date()
    buckets: dict[str, list] = {"Today": [], "Yesterday": [], "This Week": [], "Earlier": []}

    for h in items:
        delta_days = (today - h.created_at.date()).days
        if delta_days == 0:
            buckets["Today"].append(_serialize(h))
        elif delta_days == 1:
            buckets["Yesterday"].append(_serialize(h))
        elif delta_days <= 7:
            buckets["This Week"].append(_serialize(h))
        else:
            buckets["Earlier"].append(_serialize(h))

    return buckets


@router.delete("/{history_id}")
def delete_history_item(history_id: str, user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    item = db.query(models.ScanHistory).filter(
        models.ScanHistory.id == history_id, models.ScanHistory.user_id == user.id
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="History item not found")
    db.delete(item)
    db.commit()
    return {"message": "Deleted"}


@router.delete("")
def clear_history(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    db.query(models.ScanHistory).filter(models.ScanHistory.user_id == user.id).delete()
    db.commit()
    return {"message": "History cleared"}


@router.get("/export")
def export_history(
    format: str = Query(default="csv", pattern="^(csv|json)$"),
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    items = db.query(models.ScanHistory).filter(
        models.ScanHistory.user_id == user.id
    ).order_by(models.ScanHistory.created_at.desc()).all()

    if format == "json":
        return {"items": [_serialize(h) for h in items]}

    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(["Date", "Type", "Category", "Scam Type", "Risk Score", "Summary", "Advice"])
    for h in items:
        writer.writerow([
            h.created_at.isoformat(), h.scan_type, h.category, h.scam_type,
            h.risk_score, h.summary, h.advice,
        ])
    buf.seek(0)
    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=nexusshield_history.csv"},
    )
