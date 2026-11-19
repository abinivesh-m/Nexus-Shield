"""Pydantic request/response schemas for the NexusShield API."""
import datetime as dt
from pydantic import BaseModel, EmailStr, Field


# ── Auth ─────────────────────────────────────────────────────────────────────
class SignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=10, max_length=128)
    name: str = Field(default="", max_length=100)
    phone: str = Field(default="", max_length=20)


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


class OtpRequest(BaseModel):
    email: EmailStr | None = None
    phone: str | None = None
    purpose: str  # verify | reset


class OtpVerifyRequest(BaseModel):
    email: EmailStr
    otp: str = Field(min_length=6, max_length=6)
    purpose: str  # verify | reset


class OtpResetRequest(BaseModel):
    email: EmailStr
    otp: str = Field(min_length=6, max_length=6)
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
    phone: str | None = None
    language: str | None = None
    theme: str | None = None
    notif_push_enabled: bool | None = None
    notif_threat_alerts: bool | None = None
    notif_weekly_summary: bool | None = None
    security_biometric_lock: bool | None = None
    security_auto_scan_clipboard: bool | None = None


# ── Analysis ─────────────────────────────────────────────────────────────────
class ScreenshotRequest(BaseModel):
    image_base64: str = Field(max_length=8_000_000)
    language: str = "en"


class TextRequest(BaseModel):
    text: str = Field(max_length=10_000)
    language: str = "en"


class UrlRequest(BaseModel):
    url: str = Field(max_length=2048)
    language: str = "en"


class ChatRequest(BaseModel):
    message: str = Field(max_length=4000)
    history: list[dict] = Field(default_factory=list, max_length=20)
    language: str = "en"


class ClipboardCheckRequest(BaseModel):
    content: str = Field(max_length=5000)


# ── Scam Reporting ───────────────────────────────────────────────────────────
class ScamReportRequest(BaseModel):
    screenshot_base64: str | None = None
    website: str = ""
    phone_number: str = ""
    upi_id: str = ""
    description: str = ""
    category: str = "Uncategorized"

    # Geospatial Crime Intelligence (optional)
    latitude: float | None = None
    longitude: float | None = None
    city: str = ""

    # Fraud Network Intelligence (optional)
    device_id: str = ""
    bank_account: str = ""


class CurrencyAnalysisRequest(BaseModel):
    image_base64: str = Field(max_length=8_000_000)
    language: str = "en"


class CallAnalysisRequest(BaseModel):
    transcript: str = Field(max_length=20_000)
    caller_number: str = Field(default="", max_length=32)
    language: str = "en"


class InternshipAnalysisRequest(BaseModel):
    offer_text: str = Field(max_length=20_000)
    language: str = "en"


class InternshipFeedbackRequest(BaseModel):
    """A student telling us the verifier got it wrong (or right).

    `actual_verdict` is the ground truth for the pilot's accuracy numbers.
    `offer_text` is hashed server-side and never stored in clear text.
    """
    offer_text: str = ""
    history_id: str | None = None
    predicted_verdict: str = ""
    predicted_score: int = 0
    actual_verdict: str  # genuine | scam | unsure
    reason: str = ""
    notes: str = ""


class ReceiptRevokeRequest(BaseModel):
    """Revoke one receipt, or every receipt issued for the same offer."""
    receipt_id: str | None = None
    offer_hash: str | None = None
    reason: str = ""


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
