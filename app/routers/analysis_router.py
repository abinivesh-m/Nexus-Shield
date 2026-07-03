"""
Core analysis endpoints: screenshot, text, URL, and copilot chat.

Upgraded from the original prototype to:
- require auth (so results can be saved to history)
- check the local Live Scam Database first (Phase 1.5) for an instant match
- save every scan to ScanHistory (Phase 1)
- support scam categories + multi-language output (Phase 2)
- support Phase 3 "real-time protection" via the clipboard-check endpoint
"""
import socket
import urllib.parse

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models, schemas, ai_engine
from ..deps import get_current_user
from ..scam_db import check_against_db, severity_to_risk_score, extract_candidates

router = APIRouter(tags=["analysis"])


def _save_history(
    db: DBSession, user: models.User, scan_type: str, input_preview: str,
    result: dict, matched_known_scam: bool, language: str,
) -> models.ScanHistory:
    history = models.ScanHistory(
        user_id=user.id,
        scan_type=scan_type,
        input_preview=input_preview[:500],
        risk_score=result.get("risk_score", 0),
        scam_type=result.get("scam_type", "Unknown"),
        category=result.get("category", result.get("scam_type", "Unknown")),
        summary=result.get("summary", ""),
        red_flags=result.get("red_flags", []),
        advice=result.get("advice", ""),
        matched_known_scam=matched_known_scam,
        language=language,
    )
    db.add(history)
    db.commit()
    return history


def _result_from_db_match(match: dict) -> dict:
    score = severity_to_risk_score(match["severity"])
    return {
        "risk_score": score,
        "scam_type": match["category"],
        "category": match["category"],
        "summary": (
            f"This matches a known scam indicator already in NexusShield's live database "
            f"({match['matched_value']}). {match['notes']}".strip()
        ),
        "red_flags": [{"flag": "Matched known scam database entry", "detail": match["notes"] or "Reported by NexusShield users or partners."}],
        "advice": "Do not engage. Block this contact/site and report it if you haven't already.",
    }


@router.post("/analyze/screenshot")
async def analyze_screenshot(
    req: schemas.ScreenshotRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    try:
        result = ai_engine.analyze_image(req.image_base64, req.language)
        _save_history(db, user, "screenshot", "[screenshot]", result, False, req.language)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/analyze/text")
async def analyze_text(
    req: schemas.TextRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    try:
        # Phase 1.5: check live scam database first for an instant match
        match = check_against_db(db, req.text)
        if match:
            result = _result_from_db_match(match)
            _save_history(db, user, "text", req.text, result, True, req.language)
            return result

        result = ai_engine.analyze_text_content(req.text, req.language)
        _save_history(db, user, "text", req.text, result, False, req.language)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/analyze/url")
async def analyze_url(
    req: schemas.UrlRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    try:
        match = check_against_db(db, req.url)
        if match:
            result = _result_from_db_match(match)
            _save_history(db, user, "url", req.url, result, True, req.language)
            return result

        domain = urllib.parse.urlparse(req.url).netloc
        suspicious_patterns = [
            "bit.ly", "tinyurl", "t.co", "free", "prize", "win",
            "gov.in.xyz", "-india", "kyc-update", "verify-now",
        ]
        has_suspicious = any(p in req.url.lower() for p in suspicious_patterns)

        try:
            socket.gethostbyname(domain)
            resolvable = True
        except Exception:
            resolvable = False

        url_context = (
            f"URL: {req.url}\nDomain: {domain}\nResolvable: {resolvable}\n"
            f"Contains suspicious patterns: {has_suspicious}"
        )
        result = ai_engine.analyze_url_content(url_context, req.language)
        _save_history(db, user, "url", req.url, result, False, req.language)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/analyze/clipboard")
async def analyze_clipboard(
    req: schemas.ClipboardCheckRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    """
    Phase 3 — Clipboard Monitor (in-app version).

    The Flutter app calls this when it detects the user copied a URL, UPI ID,
    or crypto-wallet-looking string while NexusShield is foregrounded, using
    Flutter's Clipboard API. True OS-level background clipboard monitoring
    needs a native Android service + runtime permission and is out of scope
    for an in-app, cross-platform check — this endpoint covers the
    "warn before use" behavior whenever the app has focus.
    """
    candidates = extract_candidates(req.content)
    if not any(candidates.values()):
        return {"is_relevant": False}

    match = check_against_db(db, req.content)
    if match:
        result = _result_from_db_match(match)
        return {"is_relevant": True, "matched_known_scam": True, **result}

    # For clipboard checks we skip AI by default to keep this instant and free;
    # the user can run a full analysis from the result screen if they want one.
    risk_hint = 60 if (candidates["upi_ids"] or candidates["urls"]) else 20
    return {
        "is_relevant": True,
        "matched_known_scam": False,
        "risk_score": risk_hint,
        "candidates": candidates,
        "advice": "Double-check this before pasting it anywhere — run a full scan if you're unsure.",
    }


@router.get("/categories")
def get_categories():
    return {"categories": ai_engine.SCAM_CATEGORIES, "languages": ai_engine.LANGUAGE_NAMES}


@router.post("/copilot/chat")
async def copilot_chat(req: schemas.ChatRequest, user: models.User = Depends(get_current_user)):
    try:
        reply = ai_engine.copilot_reply(req.message, req.history, req.language)
        return {"reply": reply}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
