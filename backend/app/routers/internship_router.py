"""Internship / job offer verification endpoints."""
import html

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
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


@router.get("/r/{receipt_id}", response_class=HTMLResponse, include_in_schema=False)
def get_receipt_page(receipt_id: str, db: DBSession = Depends(get_db)):
    """The same receipt as a page a person can read.

    A placement officer should not have to read JSON to check a receipt. The
    page is deliberately dependency-free: no scripts, no fonts, no tracking.
    """
    row = db.query(models.OfferReceipt).filter(models.OfferReceipt.id == receipt_id).first()
    if not row:
        return HTMLResponse(_render_receipt_page(None, receipt_id), status_code=404)

    payload = receipts.build_payload(
        row.id, row.issued_at, row.verdict, row.risk_score,
        row.employer_domain, row.company_verified, row.offer_hash,
    )
    return HTMLResponse(
        _render_receipt_page(row, receipt_id, receipts.verify(payload, row.signature))
    )


def _render_receipt_page(row, receipt_id: str, signature_ok: bool = False) -> str:
    """Self-contained HTML. Every dynamic value is escaped."""
    esc = html.escape

    if row is None:
        headline = "Receipt not found"
        status = "No receipt with this ID exists"
        accent = "#EF4444"
        rows = ""
        note = (
            "Check the ID. Receipt IDs look like NS-7F3A9C21D0 and are printed "
            "on the verification result in the NexusShield app."
        )
    else:
        verdict = (row.verdict or "").lower()
        if not signature_ok:
            headline = "This receipt is not authentic"
            status = "Signature check failed"
            accent = "#EF4444"
            note = (
                "The stored signature does not match the receipt contents. "
                "Treat it as forged and verify the offer again."
            )
        elif row.revoked:
            headline = "Do not proceed"
            status = "Revoked"
            accent = "#EF4444"
            note = (
                "This verdict was withdrawn after the offer was confirmed as "
                "fraud"
                + (f": {esc(row.revoked_reason)}" if row.revoked_reason else "")
                + ". Ask the student for a fresh verification."
            )
        elif "scam" in verdict:
            headline = "Flagged as a scam"
            status = "Verified receipt"
            accent = "#EF4444"
            note = "Do not pay any fee, share documents, or send money to this offer."
        elif "genuine" in verdict:
            headline = "Checked and likely genuine"
            status = "Verified receipt"
            accent = "#14B8A6"
            note = (
                "This is an evidence record, not a guarantee. Confirm the offer "
                "on the employer's own website before paying anything."
            )
        else:
            headline = "Needs caution"
            status = "Verified receipt"
            accent = "#F59E0B"
            note = (
                "The verifier could not confirm this offer either way. Treat it "
                "as unverified until the employer confirms it directly."
            )

        issued = row.issued_at
        issued_text = issued.strftime("%d %b %Y, %H:%M UTC") if issued else "-"
        domain = row.employer_domain or "Not verified"
        rows = f"""
        <div class="row"><span>Receipt</span><b>{esc(row.id)}</b></div>
        <div class="row"><span>Issued</span><b>{esc(issued_text)}</b></div>
        <div class="row"><span>Verdict</span><b>{esc(row.verdict or '-')}</b></div>
        <div class="row"><span>Risk score</span><b>{int(row.risk_score or 0)} / 100</b></div>
        <div class="row"><span>Employer domain</span><b>{esc(domain)}</b></div>
        <div class="row"><span>Company verified</span><b>{"Yes" if row.company_verified else "No"}</b></div>
        <div class="row"><span>Signature</span><b>{"Valid" if signature_ok else "Invalid"}</b></div>
        """

    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>NexusShield receipt {esc(receipt_id)}</title>
<style>
  :root {{ color-scheme: dark; }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; padding: 28px 16px; background: #070B14; color: #E6EDF7;
         font: 15px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif; }}
  main {{ max-width: 520px; margin: 0 auto; }}
  .brand {{ display: flex; align-items: center; gap: 10px; margin-bottom: 22px;
            font-weight: 800; letter-spacing: -.2px; }}
  .dot {{ width: 12px; height: 12px; border-radius: 50%; background: {accent}; }}
  .card {{ background: #0E1420; border: 1px solid #1E2A3A; border-radius: 18px; padding: 22px; }}
  .status {{ display: inline-block; padding: 4px 10px; border-radius: 999px;
             font-size: 12px; font-weight: 700; color: {accent};
             background: {accent}1F; border: 1px solid {accent}44; }}
  h1 {{ font-size: 26px; line-height: 1.2; margin: 14px 0 6px; letter-spacing: -.6px; }}
  .note {{ color: #9FB0C6; font-size: 13.5px; margin: 0 0 20px; }}
  .rows {{ border-top: 1px solid #1E2A3A; }}
  .row {{ display: flex; justify-content: space-between; gap: 16px;
          padding: 10px 0; border-bottom: 1px solid #1E2A3A; font-size: 13.5px; }}
  .row span {{ color: #8A9BB1; }}
  .row b {{ text-align: right; word-break: break-word; }}
  footer {{ color: #6B7C91; font-size: 11.5px; line-height: 1.6; margin-top: 18px; }}
  a {{ color: #22D3EE; }}
</style>
</head>
<body>
<main>
  <div class="brand"><span class="dot"></span>NexusShield</div>
  <div class="card">
    <span class="status">{esc(status)}</span>
    <h1>{esc(headline)}</h1>
    <p class="note">{note}</p>
    <div class="rows">{rows}</div>
  </div>
  <footer>
    A NexusShield receipt records the verdict issued at a point in time. It can be
    revoked if the offer is later confirmed as fraud, so always open the link
    again rather than trusting a screenshot.
    Questions or a data request: <a href="mailto:abinivesh.1203@gmail.com">abinivesh.1203@gmail.com</a>
  </footer>
</main>
</body>
</html>"""
