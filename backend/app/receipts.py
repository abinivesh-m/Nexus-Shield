"""Tamper-evident verification receipts.

The idea: every other checker gives an *opinion*. An opinion cannot be
forwarded, audited, or trusted by a third party. A receipt can.

A receipt is a small, signed record of one verification:

    { id, issued_at, verdict, risk_score, employer_domain, company_verified,
      offer_hash, v }

Anyone holding the id can fetch it and check the signature. Because the
signature covers the verdict, a scammer cannot edit a "genuine" receipt into
a "scam" one or vice versa.

The part nobody else ships is *retroactive revocation*. Scam campaigns are
often only understood after the fact. If an offer that looked genuine is
later reported as fraud, every receipt for it can be revoked - and every
student holding one sees "do not proceed" instead of a stale all-clear.
A verdict is a snapshot; a receipt has a lifecycle.
"""
import hashlib
import hmac
import json
import os
import uuid
from datetime import datetime, timezone

from .auth import JWT_SECRET, _IS_PROD

RECEIPT_VERSION = 1

# Prefer a dedicated secret; fall back to the app JWT secret so local dev and
# the pilot work without extra configuration. Never hardcode a real secret.
_env_receipt = os.environ.get("RECEIPT_SECRET")
if _env_receipt:
    _SECRET = _env_receipt.encode()
elif _IS_PROD and not JWT_SECRET:
    raise RuntimeError("RECEIPT_SECRET (or JWT_SECRET) must be set in production")
else:
    _SECRET = (JWT_SECRET or "nexusshield-dev").encode()


def new_receipt_id() -> str:
    """Short, human-readable, copyable: NS-7F3A9C21D0."""
    return "NS-" + uuid.uuid4().hex[:10].upper()


def canonical(payload: dict) -> bytes:
    return json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()


def sign(payload: dict) -> str:
    return hmac.new(_SECRET, canonical(payload), hashlib.sha256).hexdigest()


def verify(payload: dict, signature: str) -> bool:
    return hmac.compare_digest(sign(payload), signature or "")


def build_payload(
    receipt_id: str,
    issued_at: datetime,
    verdict: str,
    risk_score: int,
    employer_domain: str,
    company_verified: bool,
    offer_hash: str,
) -> dict:
    """The signed body. Keep this stable - changing it invalidates old receipts."""
    if issued_at.tzinfo is None:
        issued_at = issued_at.replace(tzinfo=timezone.utc)
    return {
        "v": RECEIPT_VERSION,
        "id": receipt_id,
        "issued_at": issued_at.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "verdict": verdict or "",
        "risk_score": int(risk_score or 0),
        "employer_domain": employer_domain or "",
        "company_verified": bool(company_verified),
        "offer_hash": offer_hash or "",
    }


def issue(
    verdict: str,
    risk_score: int,
    employer_domain: str,
    company_verified: bool,
    offer_hash: str,
    receipt_id: str | None = None,
    issued_at: datetime | None = None,
) -> tuple[str, datetime, dict, str]:
    """Return (id, issued_at, payload, signature)."""
    receipt_id = receipt_id or new_receipt_id()
    issued_at = issued_at or datetime.now(timezone.utc)
    payload = build_payload(
        receipt_id, issued_at, verdict, risk_score, employer_domain,
        company_verified, offer_hash,
    )
    return receipt_id, issued_at, payload, sign(payload)
