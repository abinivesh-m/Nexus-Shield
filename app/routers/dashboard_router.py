"""Phase 4 — Security Intelligence Dashboard & Phase 10 — Personal Analytics."""
import datetime as dt

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models
from ..deps import get_current_user

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/summary")
def dashboard_summary(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    today = dt.datetime.utcnow().date()
    week_ago = dt.datetime.utcnow() - dt.timedelta(days=7)

    all_scans = db.query(models.ScanHistory).filter(models.ScanHistory.user_id == user.id).all()
    today_scans = [s for s in all_scans if s.created_at.date() == today]
    high_risk = [s for s in all_scans if s.risk_score >= 70]
    safe_scans = [s for s in all_scans if s.risk_score < 31]
    week_scans = [s for s in all_scans if s.created_at >= week_ago]

    # Weekly trend: count per day for the last 7 days
    trend = []
    for i in range(6, -1, -1):
        day = (dt.datetime.utcnow() - dt.timedelta(days=i)).date()
        count = sum(1 for s in all_scans if s.created_at.date() == day)
        trend.append({"date": day.isoformat(), "count": count})

    return {
        "today_scans": len(today_scans),
        "high_risk_detections": len(high_risk),
        "safe_scans": len(safe_scans),
        "total_scans": len(all_scans),
        "weekly_trend": trend,
        "week_scan_count": len(week_scans),
    }


@router.get("/analytics")
def personal_analytics(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    """Phase 10 — total scans, safe vs risky split, most common scam type, monthly trend."""
    all_scans = db.query(models.ScanHistory).filter(models.ScanHistory.user_id == user.id).all()

    safe = sum(1 for s in all_scans if s.risk_score < 31)
    suspicious = sum(1 for s in all_scans if 31 <= s.risk_score <= 60)
    risky = sum(1 for s in all_scans if s.risk_score > 60)

    category_counts: dict[str, int] = {}
    for s in all_scans:
        category_counts[s.category] = category_counts.get(s.category, 0) + 1
    most_common = max(category_counts.items(), key=lambda kv: kv[1])[0] if category_counts else None

    monthly: dict[str, int] = {}
    for s in all_scans:
        key = s.created_at.strftime("%Y-%m")
        monthly[key] = monthly.get(key, 0) + 1
    monthly_sorted = sorted(monthly.items())[-6:]  # last 6 months

    return {
        "total_scans": len(all_scans),
        "safe_count": safe,
        "suspicious_count": suspicious,
        "risky_count": risky,
        "most_common_scam_type": most_common,
        "category_breakdown": [{"category": k, "count": v} for k, v in category_counts.items()],
        "monthly_trend": [{"month": k, "count": v} for k, v in monthly_sorted],
    }
