"""Internship offer verifier.

Verifies a pasted internship offer by:
  1. Extracting key details (company, recruiter email, role, stipend, location) via Gemini
  2. Searching the web for the company's official website (DuckDuckGo, zero-cost)
  3. Checking domain age via WHOIS
  4. Matching the recruiter's email domain against the company's domain
  5. Applying rule-based red flags + a final Gemini verdict

Designed to follow the existing "graceful fallback" pattern: if search/WHOIS
fail or are unavailable, we still return an AI-based assessment.
"""
import hashlib
import json
import os
import re
import time
import urllib.parse
from datetime import datetime, timezone

# In-memory 24h cache: same offer text -> same result. Cuts Gemini calls ~60-70%
# because students share identical fake internship messages in WhatsApp groups.
_CACHE: dict[str, tuple[float, dict]] = {}
_CACHE_TTL = 24 * 60 * 60

try:
    from ddgs import DDGS
except Exception:  # pragma: no cover
    DDGS = None

try:
    import whois as _whois
except Exception:  # pragma: no cover
    _whois = None

from . import ai_engine


FREE_EMAIL_PROVIDERS = {
    "gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "rediffmail.com",
    "ymail.com", "live.com", "aol.com", "protonmail.com",
}

EXTRACTION_PROMPT = """Extract structured details from this internship/job offer text.

Offer text:
\"\"\"{text}\"\"\"

Respond ONLY with a JSON object, no other text, in exactly this format:
{{
  "company_name": "<company name or empty>",
  "recruiter_email": "<email address or empty>",
  "role": "<role/title or empty>",
  "stipend": "<stipend text as written, e.g. 'Rs. 30,000/month' or empty>",
  "location": "<location or empty>",
  "registration_fee": <true if any registration/processing/security fee is requested>,
  "interview_mentioned": <true if an interview/test/screening is mentioned>,
  "no_experience_claim": <true if offer explicitly says no experience required>
}}"""


def _extract_json(text: str) -> dict:
    text = (text or "").strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    try:
        return json.loads(text)
    except Exception:
        return {}


def extract_fields(offer_text: str) -> dict:
    try:
        response = ai_engine.client.models.generate_content(
            model=ai_engine.MODEL,
            contents=EXTRACTION_PROMPT.format(text=offer_text),
            config=ai_engine.types.GenerateContentConfig(
                system_instruction=ai_engine.SYSTEM_PROMPT,
                max_output_tokens=400,
                response_mime_type="application/json",
                thinking_config=ai_engine.types.ThinkingConfig(thinking_budget=0),
            ),
        )
        return _extract_json(response.text)
    except Exception:
        return {}


def _parse_stipend_number(stipend_text: str):
    if not stipend_text:
        return None
    nums = re.findall(r"[\d,]+", stipend_text)
    if not nums:
        return None
    # take the largest number found
    vals = []
    for n in nums:
        try:
            vals.append(int(n.replace(",", "")))
        except ValueError:
            pass
    return max(vals) if vals else None


def search_company(company: str, location: str):
    """Return (official_domain, results_list). Best-effort.

    Uses Google Custom Search if GOOGLE_CSE_API_KEY + GOOGLE_CSE_CX are set,
    otherwise falls back to DuckDuckGo (ddgs).
    """
    if not company:
        return None, []
    query = f"{company} {location} official website".strip()

    results = []
    cse_key = os.environ.get("GOOGLE_CSE_API_KEY", "")
    cse_cx = os.environ.get("GOOGLE_CSE_CX", "")
    if cse_key and cse_cx:
        try:
            import httpx
            resp = httpx.get(
                "https://www.googleapis.com/customsearch/v1",
                params={"key": cse_key, "cx": cse_cx, "q": query, "num": 5},
                timeout=15,
            )
            if resp.status_code == 200:
                for item in resp.json().get("items", []):
                    results.append({"title": item.get("title", ""), "href": item.get("link", ""), "body": item.get("snippet", "")})
        except Exception:
            results = []

    if not results and DDGS is not None:
        try:
            results = list(DDGS().text(query, max_results=5))
        except Exception:
            results = []

    if not results:
        return None, []

    company_l = company.lower()
    chosen = None
    for r in results:
        title = (r.get("title") or "").lower()
        body = (r.get("body") or "").lower()
        if company_l and (company_l in title or company_l in body):
            chosen = r
            break
    if chosen is None:
        chosen = results[0]
    url = chosen.get("href") or chosen.get("link") or ""
    domain = urllib.parse.urlparse(url).netloc.lower()
    if domain.startswith("www."):
        domain = domain[4:]
    return (domain if domain else None), results


def whois_age_days(domain: str):
    if not domain or _whois is None:
        return None
    try:
        w = _whois.whois(domain)
        created = w.creation_date
        if isinstance(created, list):
            created = created[0] if created else None
        if not created:
            return None
        now = datetime.now(timezone.utc) if getattr(created, "tzinfo", None) else datetime.now()
        if created.tzinfo and now.tzinfo is None:
            now = now.replace(tzinfo=timezone.utc)
        return (now - created).days
    except Exception:
        return None


def recruiter_domain(email: str) -> str:
    if not email or "@" not in email:
        return ""
    return email.strip().split("@")[-1].lower()


def _cache_key(offer_text: str, language: str) -> str:
    return hashlib.sha256((offer_text.strip().lower() + "|" + language).encode()).hexdigest()


def _fallback_result(offer_text, fields, official_domain, domain_match, red_flags, language):
    """Rule-based verdict used when Gemini is unavailable (quota/network)."""
    score = min(95, 30 + 15 * len(red_flags))
    if not red_flags:
        score = 20
    company = (fields.get("company_name") or "").strip()
    summary = (
        f"AI analysis is temporarily unavailable. Based on rule-based checks, this offer "
        f"has {len(red_flags)} red flag(s): " + ", ".join(f.get("flag", "") for f in red_flags) + "."
        if red_flags
        else "AI analysis is temporarily unavailable, but no rule-based red flags were detected."
    )
    return {
        "risk_score": score,
        "verdict": _verdict_from_score(score),
        "scam_type": "Job Scam" if red_flags else "Likely Safe",
        "category": "Job Scam" if red_flags else "Likely Safe",
        "summary": summary,
        "red_flags": red_flags,
        "advice": "Do not pay any fee or share documents until you verify the company independently. Contact the company through its official website.",
        "company_name": company,
        "company_verified": bool(official_domain),
        "official_website": f"https://{official_domain}" if official_domain else "",
        "domain_match": domain_match,
    }


def run(offer_text: str, language: str = "en") -> dict:
    # Cache check
    key = _cache_key(offer_text, language)
    cached = _CACHE.get(key)
    if cached and (time.time() - cached[0]) < _CACHE_TTL:
        return dict(cached[1])

    fields = {}
    try:
        fields = extract_fields(offer_text) or {}
    except Exception:
        fields = {}

    company = (fields.get("company_name") or "").strip()
    location = (fields.get("location") or "").strip()
    email = (fields.get("recruiter_email") or "").strip()
    stipend_text = (fields.get("stipend") or "").strip()

    official_domain, _ = search_company(company, location)
    domain_age_days = whois_age_days(official_domain) if official_domain else None

    rec_domain = recruiter_domain(email)
    domain_match = bool(rec_domain and official_domain and rec_domain == official_domain)

    red_flags = []
    if rec_domain and rec_domain in FREE_EMAIL_PROVIDERS:
        red_flags.append({"flag": "Free email provider", "detail": f"Recruiter uses {rec_domain} instead of a company domain."})
    if fields.get("registration_fee"):
        red_flags.append({"flag": "Registration fee requested", "detail": "Legitimate internships rarely charge upfront fees."})
    if not fields.get("interview_mentioned"):
        red_flags.append({"flag": "No interview process", "detail": "The offer does not mention any interview or screening step."})
    stipend_num = _parse_stipend_number(stipend_text)
    if stipend_num is not None and stipend_num > 25000 and fields.get("no_experience_claim"):
        red_flags.append({"flag": "Unrealistic stipend", "detail": f"Stipend of {stipend_text} with no experience requirement is a common scam lure."})
    if company and not official_domain:
        red_flags.append({"flag": "Company not found online", "detail": "No official website found via web search."})
    if rec_domain and official_domain and rec_domain != official_domain and rec_domain not in FREE_EMAIL_PROVIDERS:
        red_flags.append({"flag": "Domain mismatch", "detail": f"Recruiter uses {rec_domain} but company site is {official_domain}."})
    if domain_age_days is not None and domain_age_days < 180:
        red_flags.append({"flag": "Recently registered domain", "detail": f"Official domain registered {domain_age_days} days ago."})

    result = None
    try:
        result = ai_engine.analyze_internship_offer(
            offer_text=offer_text,
            fields=fields,
            official_domain=official_domain,
            domain_match=domain_match,
            domain_age_days=domain_age_days,
            red_flags=red_flags,
            language=language,
        )
    except Exception:
        result = None

    if not isinstance(result, dict):
        result = _fallback_result(offer_text, fields, official_domain, domain_match, red_flags, language)
    else:
        ai_flags = result.get("red_flags", [])
        existing = {f.get("flag") for f in red_flags}
        for f in ai_flags:
            if f.get("flag") not in existing:
                red_flags.append(f)
                existing.add(f.get("flag"))
        result["red_flags"] = red_flags
        result.setdefault("company_name", company or (result.get("company_name") or ""))
        result.setdefault("company_verified", bool(official_domain))
        result["official_website"] = f"https://{official_domain}" if official_domain else ""
        result["domain_match"] = domain_match
        result.setdefault("verdict", _verdict_from_score(result.get("risk_score", 50)))

    _CACHE[key] = (time.time(), result)
    return result


def _verdict_from_score(score: int) -> str:
    if score >= 70:
        return "Likely scam"
    if score >= 40:
        return "Suspicious"
    return "Likely genuine"
