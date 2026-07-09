"""
AI analysis engine wrapper around the Google Gemini API.

Builds on the original prototype's prompt design and extends it with:
- explicit scam category taxonomy (Phase 2)
- structured red-flag reasons returned as discrete items, not prose
- multi-language output (Phase 2)
"""
import os
import json
from pathlib import Path
from dotenv import load_dotenv
from google import genai
from google.genai import types

# Safety net if this module is imported before main.py's load_dotenv() runs.
# backend/.env is two directories up from backend/app/ai_engine.py.
load_dotenv(dotenv_path=Path(__file__).resolve().parent.parent / ".env")

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


def safe_parse_result(text: str) -> dict:
    """Extract JSON from Gemini response, handling markdown code blocks."""
    text = (text or "").strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    try:
        parsed = json.loads(text)
    except Exception:
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
            max_output_tokens=900,
            response_mime_type="application/json",
        ),
    )
    return safe_parse_result(response.text)


def analyze_text_content(text: str, language: str = "en") -> dict:
    response = client.models.generate_content(
        model=MODEL,
        contents=build_analysis_prompt(f'"{text}"', language),
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            max_output_tokens=700,
            response_mime_type="application/json",
        ),
    )
    return safe_parse_result(response.text)


def analyze_url_content(url_context: str, language: str = "en") -> dict:
    response = client.models.generate_content(
        model=MODEL,
        contents=build_analysis_prompt(url_context, language),
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            max_output_tokens=700,
            response_mime_type="application/json",
        ),
    )
    return safe_parse_result(response.text)


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
            max_output_tokens=800,
            response_mime_type="application/json",
        ),
    )
    return safe_parse_result(response.text)


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
    text = (text or "").strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    try:
        parsed = json.loads(text)
    except Exception:
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
            max_output_tokens=500,
            response_mime_type="application/json",
        ),
    )
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
            max_output_tokens=700,
        ),
    )
    return response.text
