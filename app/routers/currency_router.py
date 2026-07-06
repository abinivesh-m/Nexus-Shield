"""Counterfeit Currency Detection (prototype).

Uses Gemini Vision to give a best-effort genuine/counterfeit assessment of a
photographed banknote. This is explicitly a hackathon-prototype feature, not
a certified authentication system -- see the disclaimer baked into the
prompt in ai_engine.py and surfaced in the Flutter UI.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models, schemas, ai_engine
from ..deps import get_current_user

router = APIRouter(prefix="/analyze", tags=["currency"])


@router.post("/currency")
async def analyze_currency(
    req: schemas.CurrencyAnalysisRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    try:
        result = ai_engine.analyze_currency_image(req.image_base64, req.language)

        # Log to history alongside screenshot/text/url scans so it shows up
        # in the user's existing scan history and personal analytics.
        history = models.ScanHistory(
            user_id=user.id,
            scan_type="currency",
            input_preview="[banknote photo]",
            risk_score=0 if result.get("likely_genuine") else 80,
            scam_type="Counterfeit Currency" if not result.get("likely_genuine") else "Likely Safe",
            category="Counterfeit Currency",
            summary=", ".join(result.get("reasons", [])) or "No specific reasons returned.",
            red_flags=[{"flag": r, "detail": ""} for r in result.get("reasons", [])],
            advice=(
                "Do not accept this note; compare it against an official RBI note or hand it to a bank."
                if not result.get("likely_genuine")
                else "No obvious red flags detected, but this is a prototype check, not a guarantee."
            ),
            matched_known_scam=False,
            language=req.language,
        )
        db.add(history)
        db.commit()

        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
