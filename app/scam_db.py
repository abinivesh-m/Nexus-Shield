"""
Phase 1.5 — Live Scam Database matching.
Checks input (URL/domain/phone/UPI) against locally stored known-bad
indicators before falling back to AI analysis. This gives instant,
deterministic matches and saves an AI call when something is already
known-bad.
In production, `ingest_external_feed()` would be called on a schedule to
pull from CERT-In advisories, telecom-reported scam numbers, etc. Here it
just seeds from `seed_data.py` so the matching logic is fully real and
testable without needing live feed credentials.
"""
import re
import urllib.parse
from sqlalchemy.orm import Session as DBSession
from . import models


def extract_candidates(text: str) -> dict:
    """Pull out URLs, phone numbers, and UPI-like IDs from free text."""
    urls = re.findall(r"https?://[^\s]+|www\.[^\s]+", text)
    domains = []
    for u in urls:
        try:
            netloc = urllib.parse.urlparse(
                u if u.startswith("http") else f"http://{u}"
            ).netloc
            if netloc:
                domains.append(netloc.lower())
        except ValueError:
            # Skip malformed URLs (e.g. invalid IPv6 format)
            continue

    phones = re.findall(r"(?:\+91[\-\s]?)?[6-9]\d{9}\b", text)
    upi_ids = re.findall(r"[\w.\-]{2,256}@[a-zA-Z]{2,64}", text)
    return {
        "urls": [u.lower() for u in urls],
        "domains": domains,
        "phones": phones,
        "upi_ids": [u.lower() for u in upi_ids],
    }


def check_against_db(db: DBSession, text: str) -> dict | None:
    """
    Returns a match dict if any extracted candidate matches a known scam
    database entry, else None.
    """
    candidates = extract_candidates(text)
    all_values = (
        candidates["urls"]
        + candidates["domains"]
        + candidates["phones"]
        + candidates["upi_ids"]
    )
    if not all_values:
        return None

    entries = db.query(models.ScamDatabaseEntry).all()
    for entry in entries:
        entry_value = entry.value.lower()
        for val in all_values:
            if entry_value == val or entry_value in val or val in entry_value:
                return {
                    "matched_value": val,
                    "entry_type": entry.entry_type,
                    "category": entry.category,
                    "severity": entry.severity,
                    "notes": entry.notes,
                    "source": entry.source,
                }
    return None


def severity_to_risk_score(severity: str) -> int:
    return {"low": 35, "medium": 60, "high": 85, "critical": 97}.get(severity, 70)
