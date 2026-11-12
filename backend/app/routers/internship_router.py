"""Internship / job offer verification endpoint."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models, schemas
from ..deps import get_current_user
from .. import internship_verifier
from .analysis_router import _save_history

router = APIRouter(tags=["internship-verification"])


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
        _save_history(db, user, "internship", req.offer_text, result, False, req.language)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))