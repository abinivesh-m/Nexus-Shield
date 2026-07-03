"""Phase 4 — Security Intelligence: Threat Feed & News.

Read-only for regular users; population happens via admin/seed data or, in
production, a scheduled job hitting CERT-In/telecom feeds.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models

router = APIRouter(prefix="/intel", tags=["intelligence"])


@router.get("/threat-feed")
def get_threat_feed(region: str | None = None, db: DBSession = Depends(get_db)):
    query = db.query(models.ThreatFeedItem)
    if region:
        query = query.filter(models.ThreatFeedItem.region == region)
    items = query.order_by(models.ThreatFeedItem.published_at.desc()).limit(50).all()
    return [
        {
            "id": i.id, "title": i.title, "description": i.description, "region": i.region,
            "category": i.category, "severity": i.severity, "source": i.source,
            "published_at": i.published_at,
        }
        for i in items
    ]


@router.get("/news")
def get_news(category: str | None = None, db: DBSession = Depends(get_db)):
    query = db.query(models.NewsItem)
    if category:
        query = query.filter(models.NewsItem.category == category)
    items = query.order_by(models.NewsItem.published_at.desc()).limit(50).all()
    return [
        {
            "id": i.id, "title": i.title, "summary": i.summary, "source": i.source,
            "url": i.url, "category": i.category, "published_at": i.published_at,
        }
        for i in items
    ]
