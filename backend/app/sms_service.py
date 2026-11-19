"""SMS dispatch for NexusShield (India).

Uses Fast2SMS when FAST2SMS_API_KEY is configured. Falls back to dev mode
otherwise (caller returns the OTP in the response). Configure via env vars:
    FAST2SMS_API_KEY, FAST2SMS_SENDER_ID (optional), FAST2SMS_ROUTE (optional, default 'q')
"""
import os

import httpx

FAST2SMS_API_KEY = os.environ.get("FAST2SMS_API_KEY", "")
FAST2SMS_SENDER_ID = os.environ.get("FAST2SMS_SENDER_ID", "NEXUS")
FAST2SMS_ROUTE = os.environ.get("FAST2SMS_ROUTE", "q")


def is_configured() -> bool:
    return bool(FAST2SMS_API_KEY)


def send_sms(phone: str, message: str) -> bool:
    if not is_configured():
        return False
    try:
        resp = httpx.post(
            "https://www.fast2sms.com/dev/bulkV2",
            headers={"authorization": FAST2SMS_API_KEY},
            data={
                "route": FAST2SMS_ROUTE,
                "sender_id": FAST2SMS_SENDER_ID,
                "message": message,
                "language": "english",
                "flash": "0",
                "numbers": phone,
            },
            timeout=15,
        )
        data = resp.json()
        return bool(data.get("return"))
    except Exception:
        return False


def send_otp(phone: str, otp: str, purpose: str = "verify") -> bool:
    label = "verification" if purpose == "verify" else "password reset"
    return send_sms(
        phone,
        f"Your NexusShield {label} code is {otp}. It expires in 10 minutes. "
        f"Do not share it with anyone.",
    )
