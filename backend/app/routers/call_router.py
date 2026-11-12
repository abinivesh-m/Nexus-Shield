"""Digital Arrest / Scam Call Detection (transcript-based prototype).

Real-time audio interception of live phone calls needs a native Android
foreground service, telephony permissions, and Play Store policy review --
out of scope for a cross-platform Flutter prototype (see README.md). This
endpoint covers the scoped-down, legitimately-shippable version: the user
pastes or dictates a transcript of a call they just had (or received as a
voicemail/recording), and Gemini flags digital-arrest-style scam patterns
(authority impersonation, urgency, isolation, payment pressure) using the
same structured risk_score/red_flags schema as the other analyzers.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models, schemas, ai_engine
from ..deps import get_current_user
from .analysis_router import _save_history

router = APIRouter(tags=["call-analysis"])


@router.post("/analyze/call")
def analyze_call(
    req: schemas.CallAnalysisRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    if not req.transcript or not req.transcript.strip():
        raise HTTPException(status_code=400, detail="Provide a call transcript to analyze.")
    try:
        result = ai_engine.analyze_call_transcript(req.transcript, req.caller_number, req.language)
        preview = f"[call from {req.caller_number}] {req.transcript}" if req.caller_number else req.transcript
        _save_history(db, user, "call_transcript", preview, result, False, req.language)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
