"""Internship / job offer verification endpoints."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models, schemas, receipts
from ..deps import get_current_user
from .. import internship_verifier
from .analysis_router import _save_history

router = APIRouter(tags=["internship-verification"])

# The only values a student may report as ground truth.
ACTUAL_VERDICTS = {"genuine", "scam", "unsure"}


def _issue_receipt(db: DBSession, user: models.User, result: dict, offer_text: str) -> dict:
    """Persist a signed receipt for this verdict and return its public view."""
    rid, issued_at, payload, signature = receipts.issue(
        verdict=str(result.get("verdict") or ""),
        risk_score=int(result.get("risk_score") or 0),
        employer_domain=str(result.get("official_website") or ""),
        company_verified=bool(result.get("company_verified")),
        offer_hash=internship_verifier.offer_hash(offer_text),
    )

    db.add(models.OfferReceipt(
        id=rid,
        user_id=user.id,
        offer_hash=payload["offer_hash"],
        verdict=payload["verdict"],
        risk_score=payload["risk_score"],
        employer_domain=payload["employer_domain"],
        company_verified=payload["company_verified"],
        evidence=result.get("red_flags") or [],
        signature=signature,
        issued_at=issued_at,
    ))
    db.commit()

    return {
        "id": rid,
        "issued_at": payload["issued_at"],
        "signature": signature,
        "verify_url": f"/receipt/{rid}",
        "status": "valid",
    }


@router.post("/analyze/internship")
def analyze_internship(
    req: schemas.InternshipAnalysisRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    if not req.offer_text or not req.offer_text.strip():
        raise HTTPException(status_code=400, detail="Provide an offer text to analyze.")
    try:
        result = internship_verifier.run(req.offer_text, req.language)
        # Store a redacted preview, never the raw message.
        preview = internship_verifier.redact_offer_text(req.offer_text)
        history = _save_history(db, user, "internship", preview, result, False, req.language)
        # The app needs this id to attach a correction to the exact verdict.
        result["history_id"] = history.id
        result["receipt"] = _issue_receipt(db, user, result, req.offer_text)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/analyze/internship/feedback")
def internship_feedback(
    req: schemas.InternshipFeedbackRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    """Record what actually happened, so pilot accuracy can be measured."""
    actual = (req.actual_verdict or "").strip().lower()
    if actual not in ACTUAL_VERDICTS:
        raise HTTPException(
            status_code=400,
            detail="actual_verdict must be one of: genuine, scam, unsure",
        )

    # Only hash the offer - never persist the message itself.
    digest = internship_verifier.offer_hash(req.offer_text) if req.offer_text.strip() else ""

    feedback = models.InternshipFeedback(
        user_id=user.id,
        history_id=req.history_id or None,
        offer_hash=digest,
        predicted_verdict=(req.predicted_verdict or "")[:64],
        predicted_score=int(req.predicted_score or 0),
        actual_verdict=actual,
        reason=(req.reason or "")[:120],
        notes=(req.notes or "")[:1000],
    )
    db.add(feedback)
    db.commit()

    return {
        "id": feedback.id,
        "recorded": True,
        "message": "Thanks - this is how the verifier gets more accurate.",
    }


@router.get("/receipt/{receipt_id}")
def get_receipt(receipt_id: str, db: DBSession = Depends(get_db)):
    """Public, unauthenticated verification of a receipt.

    This is what a placement officer opens. It reveals the verdict and the
    employer domain - never the student's message or identity.
    """
    row = db.query(models.OfferReceipt).filter(models.OfferReceipt.id == receipt_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Receipt not found")

    payload = receipts.build_payload(
        row.id, row.issued_at, row.verdict, row.risk_score,
        row.employer_domain, row.company_verified, row.offer_hash,
    )

    return {
        **payload,
        "valid": receipts.verify(payload, row.signature),
        "revoked": bool(row.revoked),
        "revoked_reason": row.revoked_reason or "",
        "revoked_at": row.revoked_at,
        "evidence": row.evidence or [],
    }
