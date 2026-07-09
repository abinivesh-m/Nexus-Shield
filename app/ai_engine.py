"""
AI analysis engine wrapper around the Google Gemini API.

Builds on the original prototype's prompt design and extends it with:
- explicit scam category taxonomy (Phase 2)
- structured red-flag reasons returned as discrete items, not prose
- multi-language output (Phase 2)
"""
import os
import json
import logging
from pathlib import Path
from dotenv import load_dotenv
from google import genai
from google.genai import types

# Safety net if this module is imported before main.py's load_dotenv() runs.
# backend/.env is two directories up from backend/app/ai_engine.py.
load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

logger = logging.getLogger("nexusshield.ai_engine")

client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY", ""))

# Use a current Gemini model string. See https://ai.google.dev/gemini-api/docs/models
# for the latest available models -- update this if your account uses a different one.
MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

SCAM_CATEGORIES = [
    "Phishing", "OTP Scam", "Job Scam", "Loan Scam", "UPI Fraud",
    "Digital Arrest Scam", "Investment Scam", "Romance Scam",
    "Courier Scam", "Lottery Scam", "Likely Safe", "Unknown",
]

LANGUAGE_NAMES = {
    "en": "English",
    "ta": "Tamil",
    "hi": "Hindi",
    "kn": "Kannada",
    "te": "Telugu",
}

SYSTEM_PROMPT = """You are NexusShield AI, an expert in detecting digital scams, fraud,
and cybercrime in India. You specialize in these categories ONLY:
Phishing, OTP Scam, Job Scam, Loan Scam, UPI Fraud, Digital Arrest Scam,
Investment Scam, Romance Scam, Courier Scam, Lottery Scam.

Always respond in a helpful, clear tone. Be direct about risks.
When analyzing, always output ONLY valid JSON in the exact schema requested."""

# gemini-2.5-flash is a "thinking" model: part of max_output_tokens is spent
# on internal reasoning before it writes the visible answer. If the budget
# is too low, thinking alone can consume it all (finish_reason=MAX_TOKENS),
# truncating the response mid-JSON and causing every scan to silently fall
# through to the generic parse-failure fallback below. Every analysis call
# in this file disables thinking (thinking_budget=0) for these direct
# classification tasks and uses a generous token budget, matching the fix
# already applied to analyze_currency_image.
NO_THINKING = types.ThinkingConfig(thinking_budget=0)


def build_analysis_prompt(content_desc: str, language: str = "en") -> str:
    lang_name = LANGUAGE_NAMES.get(language, "English")
    lang_instruction = (
        f"Write the 'summary' and 'advice' fields in {lang_name}. "
        f"Keep 'scam_type' and 'category' in English so the app can match them to icons."
        if language != "en"
        else ""
    )
    return f"""Analyze the following for scam/fraud indicators: {content_desc}

Respond ONLY with a JSON object, no other text, in exactly this format:
{{
  "risk_score": <integer 0-100>,
  "scam_type": "<name of scam type or 'Likely Safe'>",
  "category": "<one of: {', '.join(SCAM_CATEGORIES)}>",
  "summary": "<2-3 sentence explanation of what you found>",
  "red_flags": [
    {{"flag": "<short red flag label, e.g. 'Urgent language'>", "detail": "<one sentence why this matters>"}}
  ],
  "advice": "<1-2 sentences on what the user should do>"
}}

Risk score guide:
- 0-30: Likely Safe
- 31-60: Suspicious, proceed with caution
- 61-80: High risk, likely scam
- 81-100: Definite scam, do not engage

{lang_instruction}"""


def _log_finish_reason(response, context: str):
    """Surfaces *why* a response came back empty/truncated (safety block,
    MAX_TOKENS, etc) instead of only seeing a generic parse failure later.
    Check server logs after a failed scan to see the real cause."""
    candidates = getattr(response, "candidates", None) or []
    if candidates:
        finish_reason = getattr(candidates[0], "finish_reason", None)
        if finish_reason and str(finish_reason) not in ("STOP", "FinishReason.STOP", "1"):
            logger.warning(
                "%s: Gemini finished with reason=%s (likely blocked/truncated), "
                "prompt_feedback=%r", context, finish_reason,
                getattr(response, "prompt_feedback", None),
            )


def safe_parse_result(text: str, context: str = "analysis") -> dict:
    """Extract JSON from Gemini response, handling markdown code blocks."""
    raw_text = text or ""
    text = raw_text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    try:
        parsed = json.loads(text)
    except Exception:
        logger.warning(
            "%s: failed to parse Gemini response as JSON. Raw text: %r",
            context, raw_text,
        )
        return {
            "risk_score": 50,
            "scam_type": "Unknown",
            "category": "Unknown",
            "summary": "Could not fully analyze. Exercise caution.",
            "red_flags": [],
            "advice": "When in doubt, do not share personal info or send money.",
        }

    # Normalize red_flags: accept either list[str] (legacy) or list[dict]
    flags = parsed.get("red_flags", [])
    normalized = []
    for f in flags:
        if isinstance(f, dict):
            normalized.append({"flag": f.get("flag", ""), "detail": f.get("detail", "")})
        else:
            normalized.append({"flag": str(f), "detail": ""})
    parsed["red_flags"] = normalized
    parsed.setdefault("category", parsed.get("scam_type", "Unknown"))
    return parsed


def analyze_image(image_base64: str, language: str = "en") -> dict:
    import base64
    image_bytes = base64.b64decode(image_base64)
    response = client.models.generate_content(
        model=MODEL,
        contents=[
            types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
            build_analysis_prompt("the screenshot above", language),
        ],
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            max_output_tokens=2000,
            response_mime_type="application/json",
            thinking_config=NO_THINKING,
        ),
    )
    _log_finish_reason(response, "Screenshot analysis")
    return safe_parse_result(response.text, "Screenshot analysis")


def analyze_text_content(text: str, language: str = "en") -> dict:
    response = client.models.generate_content(
        model=MODEL,
        contents=build_analysis_prompt(f'"{text}"', language),
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            max_output_tokens=1500,
            response_mime_type="application/json",
            thinking_config=NO_THINKING,
        ),
    )
    _log_finish_reason(response, "Text analysis")
    return safe_parse_result(response.text, "Text analysis")


def analyze_url_content(url_context: str, language: str = "en") -> dict:
    response = client.models.generate_content(
        model=MODEL,
        contents=build_analysis_prompt(url_context, language),
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            max_output_tokens=1500,
            response_mime_type="application/json",
            thinking_config=NO_THINKING,
        ),
    )
    _log_finish_reason(response, "URL analysis")
    return safe_parse_result(response.text, "URL analysis")


CALL_SYSTEM_PROMPT = """You are NexusShield AI, an expert in detecting phone-based scams in India,
especially "digital arrest" scams where callers impersonate police/CBI/customs/RBI officials,
claim a parcel/legal case implicates the victim, demand they stay on a video call, isolate them
from family, and pressure an urgent money transfer or "verification" payment to avoid arrest.

This is a PROTOTYPE that analyzes a call TRANSCRIPT (text) provided by the user after a call, or
pasted from a recording -- it does not intercept or listen to live calls. Always respond with
ONLY valid JSON in the exact schema requested."""


def build_call_prompt(transcript: str, caller_number: str = "", language: str = "en") -> str:
    lang_name = LANGUAGE_NAMES.get(language, "English")
    lang_instruction = (
        f"Write the 'summary' and 'advice' fields in {lang_name}. "
        f"Keep 'scam_type' and 'category' in English so the app can match them to icons."
        if language != "en"
        else ""
    )
    number_context = f"The call came from: {caller_number}\n" if caller_number else ""
    return f"""Analyze this phone call transcript for scam indicators, with special attention to
"digital arrest" scam patterns: authority impersonation (police/CBI/customs/RBI/courier),
manufactured urgency, threats of arrest/legal action, instructions to stay on video call or not
hang up, isolation from family/friends, requests for OTP/UPI/bank details, or pressure to
transfer money or buy gift cards to "resolve" a case.

{number_context}Transcript:
\"\"\"{transcript}\"\"\"

Respond ONLY with a JSON object, no other text, in exactly this format:
{{
  "risk_score": <integer 0-100>,
  "scam_type": "<name of scam type or 'Likely Safe'>",
  "category": "<one of: {', '.join(SCAM_CATEGORIES)}>",
  "summary": "<2-3 sentence explanation of what you found>",
  "red_flags": [
    {{"flag": "<short red flag label, e.g. 'Authority impersonation'>", "detail": "<one sentence why this matters>"}}
  ],
  "advice": "<1-2 sentences on what the user should do next>"
}}

Risk score guide:
- 0-30: Likely Safe
- 31-60: Suspicious, proceed with caution
- 61-80: High risk, likely scam
- 81-100: Definite scam, do not engage -- hang up and report to cybercrime.gov.in / 1930

{lang_instruction}"""


def analyze_call_transcript(transcript: str, caller_number: str = "", language: str = "en") -> dict:
    response = client.models.generate_content(
        model=MODEL,
        contents=build_call_prompt(transcript, caller_number, language),
        config=types.GenerateContentConfig(
            system_instruction=CALL_SYSTEM_PROMPT,
            max_output_tokens=1800,
            response_mime_type="application/json",
            thinking_config=NO_THINKING,
        ),
    )
    _log_finish_reason(response, "Call transcript analysis")
    return safe_parse_result(response.text, "Call transcript analysis")


CURRENCY_SYSTEM_PROMPT = """You are a currency authentication assistant helping build a
hackathon PROTOTYPE for detecting potentially counterfeit Indian banknotes from a photo.
This is a proof of concept, not a certified/production authentication system.
Always respond with ONLY valid JSON in the exact schema requested."""


def build_currency_prompt(language: str = "en") -> str:
    lang_name = LANGUAGE_NAMES.get(language, "English")
    lang_instruction = (
        f"Write each 'reasons' entry in {lang_name}." if language != "en" else ""
    )
    return f"""Look at this banknote photo and assess visible authentication cues such as:
- security thread/strip presence and position
- watermark visibility
- serial number formatting/consistency
- micro-lettering, color-shift ink, or texture cues if visible
- overall print quality and paper texture

Respond ONLY with a JSON object, no markdown, no backticks, in exactly this shape:
{{
  "likely_genuine": true or false,
  "confidence_percent": <integer 0-100>,
  "reasons": ["short reason 1", "short reason 2", "short reason 3"]
}}

Give your best visual assessment even if you cannot be fully certain from a photo alone.
{lang_instruction}"""


def safe_parse_currency_result(text: str) -> dict:
    raw_text = text or ""
    text = raw_text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    try:
        parsed = json.loads(text)
    except Exception:
        # Log the raw model output so failures are diagnosable instead of
        # silently collapsing to a generic message. Check server logs after
        # a failed scan to see exactly what Gemini returned.
        logger.warning(
            "Currency analysis: failed to parse Gemini response as JSON. Raw text: %r",
            raw_text,
        )
        return {
            "likely_genuine": False,
            "confidence_percent": 0,
            "reasons": ["Could not fully analyze this image. Try a clearer, well-lit photo."],
        }
    parsed.setdefault("likely_genuine", False)
    parsed.setdefault("confidence_percent", 50)
    parsed.setdefault("reasons", [])
    return parsed


def analyze_currency_image(image_base64: str, language: str = "en") -> dict:
    import base64
    image_bytes = base64.b64decode(image_base64)
    response = client.models.generate_content(
        model=MODEL,
        contents=[
            types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
            build_currency_prompt(language),
        ],
        config=types.GenerateContentConfig(
            system_instruction=CURRENCY_SYSTEM_PROMPT,
            # Raised from 500: gemini-2.5-flash is a "thinking" model that
            # spends part of max_output_tokens on internal reasoning before
            # writing the visible answer. At 500, thinking alone consumed
            # the whole budget (finish_reason=MAX_TOKENS), truncating the
            # response mid-JSON (e.g. '{"likely_genuine":') and causing
            # every scan to fall through to the parse-failure fallback.
            max_output_tokens=2000,
            response_mime_type="application/json",
            # This task is a direct visual read, not a reasoning-heavy task
            # -- disable thinking so the full token budget goes to the
            # actual JSON output instead of being silently consumed first.
            thinking_config=NO_THINKING,
        ),
    )
    _log_finish_reason(response, "Currency analysis")
    return safe_parse_currency_result(response.text)


def copilot_reply(message: str, history: list[dict], language: str = "en") -> str:
    # Gemini uses "user" / "model" roles (not "assistant"), and expects each
    # turn as a Content object with a list of Parts.
    contents = []
    for h in history[-8:]:
        role = h.get("role")
        if role == "user":
            contents.append(types.Content(role="user", parts=[types.Part.from_text(text=h["content"])]))
        elif role == "assistant":
            contents.append(types.Content(role="model", parts=[types.Part.from_text(text=h["content"])]))
    contents.append(types.Content(role="user", parts=[types.Part.from_text(text=message)]))

    lang_name = LANGUAGE_NAMES.get(language, "English")
    copilot_system = SYSTEM_PROMPT + f"""

For the copilot chat mode:
- Respond in plain conversational {lang_name} (NOT JSON)
- Be concise but thorough
- Use emojis sparingly for clarity (⚠️ for warnings, ✅ for safe, 🚨 for scams)
- Always end with a clear recommendation: what the user should DO next
- If analyzing something specific, give a risk level: Safe / Suspicious / High Risk / Definite Scam
"""
    response = client.models.generate_content(
        model=MODEL,
        contents=contents,
        config=types.GenerateContentConfig(
            system_instruction=copilot_system,
            max_output_tokens=1200,
            thinking_config=NO_THINKING,
        ),
    )
    _log_finish_reason(response, "Copilot chat")
    return response.text or "Sorry, I couldn't generate a response. Please try again."
