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

from fastapi import APIRouter, Depends
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


def _heuristic_result(kind: str, text: str, language: str = "en") -> dict:
    """Rule-based result used when the AI service is unavailable.

    A 500 page is worse than a cautious estimate. This never reports a message
    containing classic scam markers as safe, and it says plainly that the AI
    did not run. The app shows the same result card with a "degraded" note.
    """
    if kind == "screenshot":
        return {
            "risk_score": 50,
            "scam_type": "Could not be checked",
            "category": "Unknown",
            "summary": (
                "The AI image reader is temporarily unavailable, so this "
                "screenshot could not be read. That is not a sign that it is safe."
            ),
            "red_flags": [{
                "flag": "Automatic image check unavailable",
                "detail": "Paste the message as text to get a rule-based check.",
            }],
            "advice": (
                "Do not act on this message yet. Copy its text into the Message "
                "Analyzer, or contact the company on its official number."
            ),
            "degraded": True,
        }

    low = (text or "").lower()
    flags: list[dict] = []
    score = 15

    def flag(name: str, detail: str, points: int) -> None:
        nonlocal score
        if any(f["flag"] == name for f in flags):
            return
        flags.append({"flag": name, "detail": detail})
        score = min(100, score + points)

    if any(w in low for w in (
        "registration fee", "processing fee", "security deposit", "joining fee",
        "pay rs", "pay ₹", "pay inr", "advance payment", "payment of",
        "customs duty", "courier fee", "clearance fee",
    )):
        flag(
            "Payment requested upfront",
            "Genuine employers and agencies do not ask you to pay to receive a "
            "job, prize or refund.",
            35,
        )
    if any(w in low for w in ("otp", "one-time password", "cvv", "atm pin", "upi pin", "net banking password")):
        flag(
            "Asks for an OTP, PIN or password",
            "No bank, company or government office ever needs your OTP or PIN.",
            45,
        )
    if any(w in low for w in ("lottery", "prize", "you have won", "you won", "lucky winner")):
        flag(
            "Prize or lottery claim",
            "Unexpected winnings that require a payment are a standard lottery scam.",
            30,
        )
    if any(w in low for w in ("cbi", "police", "customs", "enforcement directorate", "arrest", "court case", "legal action", " fir ")):
        flag(
            "Authority or arrest threat",
            "Real agencies do not demand money over a call or chat to avoid arrest.",
            35,
        )
    if any(w in low for w in ("kyc", "account will be blocked", "account suspended", "verify your account", "reactivate")):
        flag(
            "Account-blocking pressure",
            "Banks do not send links asking you to re-verify KYC.",
            25,
        )
    if any(w in low for w in ("upi", "gpay", "phonepe", "paytm", "ybl", "okaxis", "oksbi")):
        flag(
            "Payment to a personal UPI ID",
            "Money sent to an individual UPI handle is hard to recover and is not "
            "how companies bill.",
            25,
        )
    if any(w in low for w in ("urgent", "immediately", "within 24 hours", "expires today", "last chance", "act now")):
        flag(
            "Manufactured urgency",
            "Urgency is used to stop you from checking the claim.",
            15,
        )
    if any(w in low for w in ("http://", "bit.ly", "tinyurl", "t.co", "wa.me", ".xyz", ".top", "-jobs", "kyc-update")):
        flag(
            "Suspicious or shortened link",
            "Shortened and look-alike links hide the real destination.",
            20,
        )
    if any(w in low for w in ("no interview", "no experience required", "guaranteed job", "direct joining")):
        flag(
            "Too-good-to-be-true offer",
            "Real hiring involves an interview and an employer you can verify.",
            20,
        )
    if kind == "call" and any(w in low for w in ("stay on the call", "do not hang up", "don't hang up", "video call")):
        flag(
            "Kept on the line",
            "Scammers keep victims on the call so they cannot check with family "
            "or the police.",
            25,
        )

    if "otp" in low or "cvv" in low:
        category = "OTP Scam"
    elif "upi" in low or "gpay" in low or "phonepe" in low:
        category = "UPI Fraud"
    elif "arrest" in low or "cbi" in low or "police" in low:
        category = "Digital Arrest Scam"
    elif "lottery" in low or "prize" in low or "won" in low:
        category = "Lottery Scam"
    elif "job" in low or "internship" in low or "stipend" in low or "salary" in low:
        category = "Job Scam"
    elif "http" in low or "link" in low or "kyc" in low:
        category = "Phishing"
    else:
        category = "Unknown"

    if score >= 70:
        advice = (
            "Do not pay, share documents or send money. Check the company on its "
            "official website, and report it at cybercrime.gov.in or on 1930."
        )
    elif score >= 40:
        advice = (
            "Treat this as unverified. Contact the organisation using a number or "
            "website you looked up yourself, never one from the message."
        )
    else:
        advice = (
            "No classic scam wording was found, but this was only a rule-based "
            "check. Confirm anything involving money or documents directly."
        )

    return {
        "risk_score": score,
        "scam_type": category,
        "category": category,
        "summary": (
            "The AI service is unavailable right now, so this is a rule-based "
            f"estimate from the wording. It found {len(flags)} warning sign"
            f"{'' if len(flags) == 1 else 's'}. It is not a full analysis."
        ),
        "red_flags": flags,
        "advice": advice,
        "degraded": True,
    }


def _copilot_fallback(language: str = "en") -> str:
    return (
        "The AI assistant is unavailable right now, so I cannot analyse this "
        "conversation. While it is down:\n\n"
        "1. Never pay a registration, processing or security fee to receive a "
        "job, prize or refund.\n"
        "2. Never share an OTP, UPI PIN, CVV or password.\n"
        "3. Verify the organisation on its own website, using a number you "
        "found yourself.\n"
        "4. If money has already gone, call 1930 and report at "
        "cybercrime.gov.in immediately.\n\n"
        "The Message, URL and Internship checkers still work without the AI."
    )


@router.post("/analyze/screenshot")
def analyze_screenshot(
    req: schemas.ScreenshotRequest,
    user: models.User = Depends(get_current_user),
    db: DBSession = Depends(get_db),
):
    try:
        result = ai_engine.analyze_image(req.image_base64, req.language)
    except Exception:
        result = _heuristic_result("screenshot", "", req.language)
    _save_history(db, user, "screenshot", "[screenshot]", result, False, req.language)
    return result


@router.post("/analyze/text")
def analyze_text(
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
    except Exception:
        result = _heuristic_result("text", req.text, req.language)
        _save_history(db, user, "text", req.text, result, False, req.language)
        return result


@router.post("/analyze/url")
def analyze_url(
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
    except Exception:
        result = _heuristic_result("url", req.url, req.language)
        _save_history(db, user, "url", req.url, result, False, req.language)
        return result


@router.post("/analyze/clipboard")
def analyze_clipboard(
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
def copilot_chat(req: schemas.ChatRequest, user: models.User = Depends(get_current_user)):
    try:
        reply = ai_engine.copilot_reply(req.message, req.history, req.language)
        return {"reply": reply}
    except Exception:
        return {"reply": _copilot_fallback(req.language), "degraded": True}