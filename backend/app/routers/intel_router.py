"""Phase 4 — Security Intelligence: Threat Feed & News.

Read-only for regular users; population happens via admin/seed data or, in
production, a scheduled job hitting CERT-In/telecom feeds.
"""
from fastapi import APIRouter, Depends, HTTPException
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


# ── Geospatial Crime Intelligence ────────────────────────────────────────────
@router.get("/hotspots")
def get_hotspots(category: str | None = None, db: DBSession = Depends(get_db)):
    """
    Aggregates scam reports that have a location attached into map-ready
    hotspot points, grouped by rounded lat/lng so nearby reports cluster
    into one marker instead of overlapping exactly.
    """
    query = db.query(models.ScamReport).filter(
        models.ScamReport.latitude.isnot(None),
        models.ScamReport.longitude.isnot(None),
    )
    if category:
        query = query.filter(models.ScamReport.category == category)
    reports = query.all()

    clusters: dict[tuple, dict] = {}
    for r in reports:
        # Round to ~1.1km grid cells so nearby reports in the same city cluster.
        key = (round(r.latitude, 2), round(r.longitude, 2))
        if key not in clusters:
            clusters[key] = {
                "latitude": r.latitude,
                "longitude": r.longitude,
                "city": r.city or "Unknown",
                "count": 0,
                "categories": {},
            }
        clusters[key]["count"] += 1
        clusters[key]["categories"][r.category] = clusters[key]["categories"].get(r.category, 0) + 1

    hotspots = []
    for c in clusters.values():
        top_category = max(c["categories"], key=c["categories"].get) if c["categories"] else "Uncategorized"
        hotspots.append({
            "latitude": c["latitude"],
            "longitude": c["longitude"],
            "city": c["city"],
            "report_count": c["count"],
            "top_category": top_category,
            "category_breakdown": c["categories"],
        })
    hotspots.sort(key=lambda h: h["report_count"], reverse=True)
    return hotspots


# ── Fraud Network Intelligence ───────────────────────────────────────────────
_LINK_FIELDS = ["phone_number", "upi_id", "website", "device_id", "bank_account"]
_FIELD_LABELS = {
    "phone_number": "Phone Number",
    "upi_id": "UPI ID",
    "website": "Website",
    "device_id": "Device ID",
    "bank_account": "Bank Account",
}


def _entity_node_id(field: str, value: str) -> str:
    return f"{field}:{value.lower().strip()}"


@router.get("/fraud-network")
def get_fraud_network(value: str, db: DBSession = Depends(get_db)):
    """
    Builds a small graph of linked fraud entities starting from a single
    identifier (phone number, UPI ID, website, device ID, or bank account).

    Traversal: find every report containing `value` in any linkable field,
    then pull in every *other* identifier those reports also contain (depth
    1). This surfaces "this phone number was used with these 3 UPI IDs and
    this device ID across 12 scam reports" style connections without
    needing a full graph database for a prototype.
    """
    value_norm = value.lower().strip()
    if not value_norm:
        raise HTTPException(status_code=400, detail="Provide a value to search for (phone, UPI ID, website, etc.)")

    matching_reports = []
    for field in _LINK_FIELDS:
        matches = db.query(models.ScamReport).filter(
            getattr(models.ScamReport, field) != "",
            getattr(models.ScamReport, field).isnot(None),
        ).all()
        for r in matches:
            if value_norm in (getattr(r, field) or "").lower():
                matching_reports.append(r)

    # De-dupe while preserving order.
    seen_ids = set()
    reports = []
    for r in matching_reports:
        if r.id not in seen_ids:
            seen_ids.add(r.id)
            reports.append(r)

    if not reports:
        return {"query": value, "nodes": [], "edges": [], "report_count": 0}

    nodes: dict[str, dict] = {}
    edges: list[dict] = []
    report_count_by_node: dict[str, int] = {}

    for r in reports:
        present = [(f, getattr(r, f)) for f in _LINK_FIELDS if getattr(r, f)]
        node_ids_this_report = []
        for field, val in present:
            node_id = _entity_node_id(field, val)
            node_ids_this_report.append(node_id)
            if node_id not in nodes:
                nodes[node_id] = {
                    "id": node_id,
                    "type": field,
                    "type_label": _FIELD_LABELS.get(field, field),
                    "value": val,
                }
            report_count_by_node[node_id] = report_count_by_node.get(node_id, 0) + 1
        # Connect every pair of identifiers that co-occur on this report.
        for i in range(len(node_ids_this_report)):
            for j in range(i + 1, len(node_ids_this_report)):
                edges.append({
                    "source": node_ids_this_report[i],
                    "target": node_ids_this_report[j],
                    "report_id": r.id,
                    "category": r.category,
                })

    for node_id, node in nodes.items():
        node["linked_report_count"] = report_count_by_node.get(node_id, 0)

    return {
        "query": value,
        "nodes": list(nodes.values()),
        "edges": edges,
        "report_count": len(reports),
    }
