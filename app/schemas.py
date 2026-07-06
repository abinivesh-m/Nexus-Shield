"""Pydantic request/response schemas for the NexusShield API."""
import datetime as dt
from pydantic import BaseModel, EmailStr, Field


# ── Auth ─────────────────────────────────────────────────────────────────────
class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    name: str = ""


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    device_label: str = "Unknown device"


class OAuthLoginRequest(BaseModel):
    provider: str  # google | apple
    id_token: str  # in production: verified against Google/Apple public keys
    email: EmailStr
    name: str = ""
    photo_url: str = ""
    device_label: str = "Unknown device"


class RefreshRequest(BaseModel):
    refresh_token: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str = Field(min_length=8)


class VerifyEmailRequest(BaseModel):
    token: str


class AuthTokens(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


# ── Profile ──────────────────────────────────────────────────────────────────
class ProfileUpdateRequest(BaseModel):
    name: str | None = None
    photo_url: str | None = None
    language: str | None = None
    theme: str | None = None
    notif_push_enabled: bool | None = None
    notif_threat_alerts: bool | None = None
    notif_weekly_summary: bool | None = None
    security_biometric_lock: bool | None = None
    security_auto_scan_clipboard: bool | None = None


# ── Analysis ─────────────────────────────────────────────────────────────────
class ScreenshotRequest(BaseModel):
    image_base64: str
    language: str = "en"


class TextRequest(BaseModel):
    text: str
    language: str = "en"


class UrlRequest(BaseModel):
    url: str
    language: str = "en"


class ChatRequest(BaseModel):
    message: str
    history: list[dict] = []
    language: str = "en"


class ClipboardCheckRequest(BaseModel):
    content: str


# ── Scam Reporting ───────────────────────────────────────────────────────────
class ScamReportRequest(BaseModel):
    screenshot_base64: str | None = None
    website: str = ""
    phone_number: str = ""
    upi_id: str = ""
    description: str = ""
    category: str = "Uncategorized"


class ReportReviewRequest(BaseModel):
    status: str  # verified | rejected
    admin_notes: str = ""


# ── Scam DB admin management ────────────────────────────────────────────────
class ScamDbEntryRequest(BaseModel):
    entry_type: str  # url | domain | phone | upi
    value: str
    category: str = "Uncategorized"
    severity: str = "high"
    notes: str = ""


# ── Family Protection ────────────────────────────────────────────────────────
class FamilyInviteRequest(BaseModel):
    member_email: EmailStr
    member_label: str = "Family member"
    min_risk_to_alert: int = 70


# ── Organization ─────────────────────────────────────────────────────────────
class OrgCreateRequest(BaseModel):
    name: str


class OrgInviteRequest(BaseModel):
    email: EmailStr


# ── Notifications ────────────────────────────────────────────────────────────
class NotificationMarkReadRequest(BaseModel):
    notification_id: str
    class CurrencyAnalysisRequest(BaseModel):
    image_base64: str
    language: str = "en"
