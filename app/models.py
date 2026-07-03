"""
NexusShield ORM models.

Covers Phase 1–10 from the production roadmap:
users/auth, profiles, analysis history, scam reporting, the local scam
database, family protection, organizations/enterprise, admin/audit,
threat feed + news, and notifications.
"""
import uuid
import datetime as dt

from sqlalchemy import (
    Column, String, Integer, Float, Boolean, DateTime, ForeignKey, Text, JSON
)
from sqlalchemy.orm import relationship

from .database import Base


def gen_id() -> str:
    return uuid.uuid4().hex


def now() -> dt.datetime:
    return dt.datetime.utcnow()


# ── Phase 1: Users / Auth / Profile ─────────────────────────────────────────
class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=gen_id)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=True)  # null if OAuth-only account
    name = Column(String, default="")
    photo_url = Column(String, default="")
    auth_provider = Column(String, default="password")  # password | google | apple

    is_email_verified = Column(Boolean, default=False)
    is_admin = Column(Boolean, default=False)

    language = Column(String, default="en")  # en, ta, hi, kn, te
    theme = Column(String, default="dark")   # dark | light

    notif_push_enabled = Column(Boolean, default=True)
    notif_threat_alerts = Column(Boolean, default=True)
    notif_weekly_summary = Column(Boolean, default=True)

    security_biometric_lock = Column(Boolean, default=False)
    security_auto_scan_clipboard = Column(Boolean, default=True)

    organization_id = Column(String, ForeignKey("organizations.id"), nullable=True)

    created_at = Column(DateTime, default=now)
    last_login_at = Column(DateTime, nullable=True)

    history = relationship("ScanHistory", back_populates="user", cascade="all, delete-orphan")
    reports = relationship("ScamReport", back_populates="reporter", cascade="all, delete-orphan")
    sessions = relationship("Session", back_populates="user", cascade="all, delete-orphan")


class Session(Base):
    """Tracks active sessions/refresh tokens for session management."""
    __tablename__ = "sessions"

    id = Column(String, primary_key=True, default=gen_id)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    refresh_token = Column(String, unique=True, index=True, nullable=False)
    device_label = Column(String, default="Unknown device")
    created_at = Column(DateTime, default=now)
    last_active_at = Column(DateTime, default=now)
    revoked = Column(Boolean, default=False)

    user = relationship("User", back_populates="sessions")


class EmailToken(Base):
    """Used for both email-verification and password-reset tokens."""
    __tablename__ = "email_tokens"

    id = Column(String, primary_key=True, default=gen_id)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    token = Column(String, unique=True, index=True, nullable=False)
    kind = Column(String, nullable=False)  # verify | reset
    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, default=False)


# ── Phase 1: Analysis History ───────────────────────────────────────────────
class ScanHistory(Base):
    __tablename__ = "scan_history"

    id = Column(String, primary_key=True, default=gen_id)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)

    scan_type = Column(String, nullable=False)  # screenshot | text | url | sms | call
    input_preview = Column(Text, default="")    # short preview of what was scanned
    risk_score = Column(Integer, default=0)
    scam_type = Column(String, default="Unknown")
    category = Column(String, default="Uncategorized")
    summary = Column(Text, default="")
    red_flags = Column(JSON, default=list)
    advice = Column(Text, default="")
    matched_known_scam = Column(Boolean, default=False)
    language = Column(String, default="en")

    created_at = Column(DateTime, default=now)

    user = relationship("User", back_populates="history")


# ── Phase 1: Scam Reporting ──────────────────────────────────────────────────
class ScamReport(Base):
    __tablename__ = "scam_reports"

    id = Column(String, primary_key=True, default=gen_id)
    reporter_id = Column(String, ForeignKey("users.id"), nullable=False)

    screenshot_path = Column(String, default="")
    website = Column(String, default="")
    phone_number = Column(String, default="")
    upi_id = Column(String, default="")
    description = Column(Text, default="")
    category = Column(String, default="Uncategorized")

    status = Column(String, default="pending")  # pending | verified | rejected
    admin_notes = Column(Text, default="")
    reviewed_by = Column(String, default="")
    reviewed_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, default=now)

    reporter = relationship("User", back_populates="reports")


# ── Phase 1: Live Scam Database ─────────────────────────────────────────────
class ScamDatabaseEntry(Base):
    """
    Unified table for known-bad indicators: phishing URLs/domains,
    scam phone numbers, and fake UPI IDs. `entry_type` discriminates.
    """
    __tablename__ = "scam_database"

    id = Column(String, primary_key=True, default=gen_id)
    entry_type = Column(String, nullable=False)  # url | domain | phone | upi
    value = Column(String, nullable=False, index=True)
    category = Column(String, default="Uncategorized")
    severity = Column(String, default="high")  # low | medium | high | critical
    source = Column(String, default="admin")   # admin | report | external_feed
    notes = Column(Text, default="")
    added_at = Column(DateTime, default=now)


# ── Phase 5: Family Protection ──────────────────────────────────────────────
class FamilyLink(Base):
    __tablename__ = "family_links"

    id = Column(String, primary_key=True, default=gen_id)
    guardian_id = Column(String, ForeignKey("users.id"), nullable=False)
    member_id = Column(String, ForeignKey("users.id"), nullable=False)
    member_label = Column(String, default="Family member")
    alerts_enabled = Column(Boolean, default=True)
    min_risk_to_alert = Column(Integer, default=70)
    created_at = Column(DateTime, default=now)


# ── Phase 5: Organizations / Enterprise ─────────────────────────────────────
class Organization(Base):
    __tablename__ = "organizations"

    id = Column(String, primary_key=True, default=gen_id)
    name = Column(String, nullable=False)
    plan = Column(String, default="enterprise")
    created_at = Column(DateTime, default=now)

    members = relationship("User", backref="organization")


# ── Phase 4: Threat Feed & News ─────────────────────────────────────────────
class ThreatFeedItem(Base):
    __tablename__ = "threat_feed"

    id = Column(String, primary_key=True, default=gen_id)
    title = Column(String, nullable=False)
    description = Column(Text, default="")
    region = Column(String, default="India")
    category = Column(String, default="Uncategorized")
    severity = Column(String, default="medium")
    source = Column(String, default="NexusShield Intelligence")
    published_at = Column(DateTime, default=now)


class NewsItem(Base):
    __tablename__ = "news_items"

    id = Column(String, primary_key=True, default=gen_id)
    title = Column(String, nullable=False)
    summary = Column(Text, default="")
    source = Column(String, default="")
    url = Column(String, default="")
    category = Column(String, default="general")  # general | advisory | cert-in
    published_at = Column(DateTime, default=now)


# ── Phase 9: Notifications ──────────────────────────────────────────────────
class Notification(Base):
    __tablename__ = "notifications"

    id = Column(String, primary_key=True, default=gen_id)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    title = Column(String, nullable=False)
    body = Column(Text, default="")
    kind = Column(String, default="alert")  # alert | weekly_summary | family | system
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=now)


# ── Phase 7: External Integration Cache (optional enrichment results) ──────
class EnrichmentCache(Base):
    """
    Caches results from external integrations (Safe Browsing, VirusTotal,
    AbuseIPDB, HIBP, CERT-In). Populated only if the relevant API key is
    configured in environment variables; otherwise these stay empty and
    the app gracefully falls back to AI-only + local scam DB analysis.
    """
    __tablename__ = "enrichment_cache"

    id = Column(String, primary_key=True, default=gen_id)
    indicator = Column(String, index=True, nullable=False)
    provider = Column(String, nullable=False)  # safe_browsing | virustotal | abuseipdb | hibp
    result_json = Column(JSON, default=dict)
    fetched_at = Column(DateTime, default=now)
