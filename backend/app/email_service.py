"""Email dispatch for NexusShield.

Uses SMTP when SMTP_HOST/SMTP_USER/SMTP_PASSWORD are configured in the
environment. Otherwise falls back to "dev mode" — the caller is expected
to return the token/OTP in the API response so the app can display it
during development (never in production).
"""
import os
import smtplib
from email.message import EmailMessage

SMTP_HOST = os.environ.get("SMTP_HOST", "")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD", "")
SMTP_FROM = os.environ.get("SMTP_FROM", SMTP_USER or "noreply@nexusshield.app")
SMTP_USE_TLS = os.environ.get("SMTP_USE_TLS", "true").lower() == "true"


def is_configured() -> bool:
    return bool(SMTP_HOST and SMTP_USER and SMTP_PASSWORD)


def send_email(to: str, subject: str, body: str) -> bool:
    """Returns True if sent successfully, False otherwise."""
    if not is_configured():
        return False
    try:
        msg = EmailMessage()
        msg["From"] = SMTP_FROM
        msg["To"] = to
        msg["Subject"] = subject
        msg.set_content(body)
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=15) as server:
            if SMTP_USE_TLS:
                server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)
        return True
    except Exception:
        return False


def send_verification_otp(email: str, otp: str) -> bool:
    return send_email(
        email,
        "NexusShield — Verify your email",
        f"Your NexusShield verification code is: {otp}\n\n"
        f"This code expires in 10 minutes. If you did not request this, ignore this email.",
    )


def send_reset_link(email: str, token: str, base_url: str = "") -> bool:
    link = f"{base_url}/reset-password?token={token}" if base_url else f"Token: {token}"
    return send_email(
        email,
        "NexusShield — Reset your password",
        f"You requested a password reset for your NexusShield account.\n\n"
        f"Reset link: {link}\n\n"
        f"This link expires in 2 hours. If you did not request this, ignore this email.",
    )


def send_reset_otp(email: str, otp: str) -> bool:
    return send_email(
        email,
        "NexusShield — Reset your password",
        f"Your NexusShield password reset code is: {otp}\n\n"
        f"This code expires in 10 minutes. If you did not request this, ignore this email.",
    )
