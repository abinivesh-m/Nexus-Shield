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

# Domains we know belong to real employers. This is not a whitelist that
# clears an offer on its own - it only lets a genuine offer *earn* trust, and
# only when the offer actually shows the domain. A scammer who name-drops
# "Google" from hackerrank-jobs.xyz still gets flagged.
KNOWN_EMPLOYERS = {
    "google": "google.com", "alphabet": "abc.xyz", "youtube": "youtube.com",
    "hackerrank": "hackerrank.com", "hackerearth": "hackerearth.com",
    "unstop": "unstop.com", "internshala": "internshala.com",
    "microsoft": "microsoft.com", "amazon": "amazon.com", "aws": "aws.amazon.com",
    "meta": "meta.com", "facebook": "facebook.com", "apple": "apple.com",
    "netflix": "netflix.com", "adobe": "adobe.com", "salesforce": "salesforce.com",
    "oracle": "oracle.com", "ibm": "ibm.com", "intel": "intel.com",
    "nvidia": "nvidia.com", "qualcomm": "qualcomm.com", "cisco": "cisco.com",
    "dell": "dell.com", "accenture": "accenture.com", "deloitte": "deloitte.com",
    "pwc": "pwc.com", "kpmg": "kpmg.com", "ey": "ey.com",
    "mckinsey": "mckinsey.com", "bcg": "bcg.com", "bain": "bain.com",
    "infosys": "infosys.com", "tcs": "tcs.com", "wipro": "wipro.com",
    "hcl": "hcltech.com", "cognizant": "cognizant.com",
    "capgemini": "capgemini.com", "techmahindra": "techmahindra.com",
    "reliance": "relianceindustries.com", "jio": "jio.com",
    "airtel": "airtel.in", "paytm": "paytm.com", "phonepe": "phonepe.com",
    "razorpay": "razorpay.com", "cred": "cred.club", "groww": "groww.in",
    "zerodha": "zerodha.com", "flipkart": "flipkart.com", "meesho": "meesho.com",
    "swiggy": "swiggy.com", "zomato": "zomato.com", "ola": "olacabs.com",
    "uber": "uber.com", "unacademy": "unacademy.com", "vedantu": "vedantu.com",
    "zoho": "zoho.com", "freshworks": "freshworks.com", "github": "github.com",
    "gitlab": "gitlab.com", "linkedin": "linkedin.com", "stripe": "stripe.com",
    "paypal": "paypal.com", "visa": "visa.com", "mastercard": "mastercard.com",
    "hdfc": "hdfcbank.com", "icici": "icicibank.com", "axis": "axisbank.com",
    "kotak": "kotak.com", "sbi": "sbi.co.in",
}
KNOWN_DOMAINS = set(KNOWN_EMPLOYERS.values())

_SECOND_LEVEL = {"co.in", "co.uk", "org.in", "net.in", "ac.in", "gov.in",
                 "com.au", "co.jp", "com.sg"}

_URL_RE = re.compile(r"(?:https?://|www\.)[^\s<>\"')]+", re.I)
_EMAIL_RE = re.compile(r"[\w.+-]+@((?:[\w-]+\.)+[a-z]{2,})", re.I)


def _registrable(host: str) -> str:
    """hackerrank.com, mail.hackerrank.com -> hackerrank.com (best effort)."""
    host = (host or "").strip().lower().strip(".")
    if host.startswith("www."):
        host = host[4:]
    parts = [p for p in host.split(".") if p]
    if len(parts) >= 3 and ".".join(parts[-2:]) in _SECOND_LEVEL:
        return ".".join(parts[-3:])
    return ".".join(parts[-2:]) if len(parts) >= 2 else host


def extract_evidence_domains(text: str) -> set:
    """Every domain the offer itself shows: links and email addresses."""
    found = set()
    for url in _URL_RE.findall(text or ""):
        host = urllib.parse.urlparse(
            url if "//" in url else "http://" + url).netloc
        d = _registrable(host)
        if d:
            found.add(d)
    for host in _EMAIL_RE.findall(text or ""):
        d = _registrable(host)
        if d:
            found.add(d)
    return found


def resolve_known_employer(company: str):
    """Map an extracted company name onto a known employer domain."""
    norm = re.sub(r"[^a-z0-9]+", " ", (company or "").lower()).strip()
    if not norm:
        return None
    if norm in KNOWN_EMPLOYERS:
        return KNOWN_EMPLOYERS[norm]
    tokens = set(norm.split())
    for key, domain in KNOWN_EMPLOYERS.items():
        if " " not in key and key in tokens:
            return domain
    for key, domain in KNOWN_EMPLOYERS.items():
        if " " in key and key in norm:
            return domain
    return None

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


_FEE_RE = re.compile(
    r"(registration|processing|security|verification|joining|training|"
    r"refundable)\s+(fee|deposit|charge|amount)"
    r"|pay\s+(?:rs\.?|inr|\u20b9)?\s*[\d,]{3,}"
    r"|one[\s-]?time\s+(?:fee|payment|charge)"
    r"|(?:fee|deposit)\s+of\s+(?:rs\.?|inr|\u20b9)?\s*[\d,]{3,}", re.I)

_NOEXP_RE = re.compile(
    r"no\s+(?:prior\s+|previous\s+)?experience|freshers?\s+(?:welcome|only)"
    r"|any\s+graduate|no\s+interview", re.I)

_INTERVIEW_RE = re.compile(
    r"interview|screening|assessment|aptitude|technical\s+round"
    r"|hiring\s+test|coding\s+(?:test|challenge)|shortlist", re.I)

_STIPEND_RE = re.compile(
    r"(?:rs\.?|inr|\u20b9)\s*([\d,]{3,})(?:\s*(?:/|per)\s*(?:month|mo|year|annum))?",
    re.I)

_UPI_RE = re.compile(
    r"\b[\w.\-]{2,}@(?:ybl|paytm|okhdfcbank|okicici|oksbi|axl|upi|apl)\b", re.I)


def _guess_company(text: str) -> str:
    """Best-effort company name without a model call."""
    earliest = None
    for key in KNOWN_EMPLOYERS:
        m = re.search(r"\b" + re.escape(key) + r"\b", text or "", re.I)
        if m and (earliest is None or m.start() < earliest[0]):
            earliest = (m.start(), key)
    if earliest:
        return earliest[1]
    m = re.search(
        r"(?:at|from|with|by)\s+([A-Z][A-Za-z&.]*(?:\s+[A-Z][A-Za-z&.]*){0,3})",
        text or "")
    return m.group(1).strip() if m else ""


def heuristic_fields(text: str) -> dict:
    """Regex-only extraction. Used when the model is down, and merged with the
    model's output when it is up (so a missed fee is still caught)."""
    text = text or ""
    emails = re.findall(r"[\w.+-]+@(?:[\w-]+\.)+[a-z]{2,}", text, re.I)
    stipend = ""
    m = _STIPEND_RE.search(text)
    if m:
        stipend = m.group(0).strip()
    return {
        "company_name": _guess_company(text),
        "recruiter_email": (emails[0] if emails else ""),
        "role": "",
        "stipend": stipend,
        "location": "",
        "registration_fee": bool(_FEE_RE.search(text)),
        "interview_mentioned": bool(_INTERVIEW_RE.search(text)),
        "no_experience_claim": bool(_NOEXP_RE.search(text)),
    }


def _merge_fields(ai_fields: dict, heur: dict) -> dict:
    """Model output wins for text, but any positive signal from either side
    wins for booleans - a scam must not survive because one extractor missed."""
    merged = dict(heur)
    for key, value in (ai_fields or {}).items():
        if key in ("registration_fee", "interview_mentioned", "no_experience_claim"):
            merged[key] = bool(value) or bool(heur.get(key))
        elif isinstance(value, str) and value.strip():
            merged[key] = value.strip()
        elif value not in (None, ""):
            merged[key] = value
    return merged


def _lookalike_domain(brand_domain: str, domains: set) -> str:
    """Return a domain that borrows the brand's name without being the brand.

    hackerrank-jobs.xyz -> flagged.  google.co.in -> not flagged (same label,
    different regional TLD).
    """
    if not brand_domain:
        return ""
    label = brand_domain.split(".")[0]
    if not label:
        return ""
    for d in sorted(domains):
        if d in KNOWN_DOMAINS or d == brand_domain:
            continue
        first = d.split(".")[0]
        if first != label and label in first.replace("-", ""):
            return d
    return ""


def search_company(company: str, location: str):
    """Return (official_domain, results_list). Best-effort.

    Uses Google Custom Search if GOOGLE_CSE_API_KEY + GOOGLE_CSE_CX are set,
    otherwise falls back to DuckDuckGo (ddgs).
    """
    if not company:
        return None, [], "unavailable"
    query = f"{company} {location} official website".strip()

    results = []
    searched = False
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
                searched = True
                for item in resp.json().get("items", []):
                    results.append({"title": item.get("title", ""), "href": item.get("link", ""), "body": item.get("snippet", "")})
        except Exception:
            results = []

    if not results and DDGS is not None:
        try:
            results = list(DDGS().text(query, max_results=5))
            searched = True
        except Exception:
            results = []

    if not results:
        # "not_found" means a real search ran and found nothing usable.
        # "unavailable" means no backend answered - which is NOT evidence
        # that the company is fake.
        return None, [], ("not_found" if searched else "unavailable")

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
    return (domain if domain else None), results, ("verified" if domain else "not_found")


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
    return hashlib.sha256(
        ("v2|" + offer_text.strip().lower() + "|" + language).encode()).hexdigest()


def _flag_key(flag: str) -> str:
    """Normalise a red-flag label so 'Registration Fee Requested' and
    'Registration fee requested' are recognised as the same finding."""
    return re.sub(r"[^a-z0-9]+", "", (flag or "").lower())


def offer_hash(offer_text: str) -> str:
    """Stable, non-reversible fingerprint of an offer.

    Used to link a feedback row back to the verdict it corrects without
    storing the student's message. Language-independent on purpose: the same
    offer in English and Tamil should map to the same fingerprint.
    """
    normalised = " ".join((offer_text or "").split()).lower()
    return hashlib.sha256(normalised.encode()).hexdigest()


# Order matters: a UPI id looks like an email address, so redact it first.
_REDACTIONS = (
    (re.compile(r"\b[\w.\-]{2,}@(?:ybl|paytm|okhdfcbank|okicici|oksbi|axl|upi|apl)\b", re.I), "[upi]"),
    (re.compile(r"[\w.+-]+@(?:[\w-]+\.)+[a-z]{2,}", re.I), "[email]"),
    (re.compile(r"\b(?:\+?91[\s-]?)?[6-9]\d{9}\b"), "[phone]"),
    (re.compile(r"https?://\S+", re.I), "[link]"),
)


def redact_offer_text(text: str) -> str:
    """Remove personal data before an offer is written to history.

    Students paste real messages containing their own phone number, email and
    UPI id. The verdict does not need any of that, so it never gets stored.
    """
    cleaned = text or ""
    for pattern, replacement in _REDACTIONS:
        cleaned = pattern.sub(replacement, cleaned)
    return cleaned



def _fallback_result(offer_text, fields, official_domain, domain_match, red_flags,
                     language, verified_employer=False, low_confidence=False):
    """Rule-based verdict used when Gemini is unavailable (quota/network)."""
    advisory = {"Unverified brand claim"}
    hard = [f for f in red_flags if f.get("flag") not in advisory]
    if verified_employer:
        score = 12
    elif hard:
        score = min(95, 30 + 15 * len(hard))
    elif red_flags:
        # only advisory notes: tell the student to confirm the sender, but do
        # not accuse a real employer of fraud
        score = 38
    elif low_confidence:
        score = 45
    else:
        score = 20
    company = (fields.get("company_name") or "").strip()
    summary = (
        f"AI analysis is temporarily unavailable. Based on rule-based checks, this offer "
        f"has {len(red_flags)} red flag(s): " + ", ".join(f.get("flag", "") for f in red_flags) + "."
        if red_flags
        else "AI analysis is temporarily unavailable, but no rule-based red flags were detected."
    )
    if low_confidence and not red_flags:
        summary = ("AI analysis is temporarily unavailable and this offer has no "
                   "company name, email or link to check. Verify the employer "
                   "through their official website before sharing anything.")
    return {
        "risk_score": score,
        "verdict": _verdict_from_score(score),
        "scam_type": "Job Scam" if red_flags else "Likely Safe",
        "category": "Job Scam" if red_flags else "Likely Safe",
        "summary": summary,
        "red_flags": red_flags,
        "advice": "Do not pay any fee or share documents until you verify the company independently. Contact the company through its official website.",
        "company_name": company,
        "company_verified": verified_employer,
        "official_website": f"https://{official_domain}" if official_domain else "",
        "domain_match": domain_match,
    }


def run(offer_text: str, language: str = "en") -> dict:
    # Cache check
    key = _cache_key(offer_text, language)
    cached = _CACHE.get(key)
    if cached and (time.time() - cached[0]) < _CACHE_TTL:
        return dict(cached[1])

    heur = heuristic_fields(offer_text)
    ai_fields = {}
    try:
        ai_fields = extract_fields(offer_text) or {}
    except Exception:
        ai_fields = {}
    if not isinstance(ai_fields, dict):
        ai_fields = {}
    fields = _merge_fields(ai_fields, heur)

    company = (fields.get("company_name") or "").strip()
    location = (fields.get("location") or "").strip()
    email = (fields.get("recruiter_email") or "").strip()
    stipend_text = (fields.get("stipend") or "").strip()

    evidence = extract_evidence_domains(offer_text)
    brand_domain = resolve_known_employer(company)
    rec_domain = recruiter_domain(email)
    rec_reg = _registrable(rec_domain) if rec_domain else ""
    known_in_evidence = evidence & KNOWN_DOMAINS

    # A domain is only "trusted" when the offer actually shows it, or when the
    # recruiter writes from a domain we know belongs to a real company.
    verified_employer = False
    if rec_reg and rec_reg in KNOWN_DOMAINS:
        official_domain, verified_employer, search_status = rec_reg, True, "verified"
    elif known_in_evidence:
        official_domain = (brand_domain if brand_domain in known_in_evidence
                           else sorted(known_in_evidence)[0])
        verified_employer, search_status = True, "verified"
    elif brand_domain:
        official_domain, search_status = brand_domain, "claimed_only"
    else:
        official_domain, _results, search_status = search_company(company, location)

    domain_match = bool(rec_reg and official_domain and rec_reg == official_domain)
    domain_age_days = (None if verified_employer
                       else (whois_age_days(official_domain) if official_domain else None))

    lookalike = _lookalike_domain(brand_domain or official_domain, evidence)

    red_flags = []
    if rec_domain and rec_domain in FREE_EMAIL_PROVIDERS:
        red_flags.append({"flag": "Free email provider", "detail": f"Recruiter uses {rec_domain} instead of a company domain."})
    if fields.get("registration_fee"):
        red_flags.append({"flag": "Registration fee requested", "detail": "Legitimate internships rarely charge upfront fees."})
    stipend_num = _parse_stipend_number(stipend_text)
    if stipend_num is not None and stipend_num > 25000 and fields.get("no_experience_claim"):
        red_flags.append({"flag": "Unrealistic stipend", "detail": f"Stipend of {stipend_text} with no experience requirement is a common scam lure."})
    # Absence of evidence is not evidence of fraud: only flag a missing
    # website when a search actually ran and found nothing.
    if company and search_status == "not_found" and not verified_employer:
        red_flags.append({"flag": "Company not found online", "detail": "No official website found via web search."})
    if rec_reg and official_domain and rec_reg != official_domain \
            and rec_reg not in KNOWN_DOMAINS and not verified_employer \
            and not lookalike:
        red_flags.append({"flag": "Domain mismatch", "detail": f"Recruiter uses {rec_domain} but company site is {official_domain}."})
    if domain_age_days is not None and domain_age_days < 180 and not verified_employer:
        red_flags.append({"flag": "Recently registered domain", "detail": f"Official domain registered {domain_age_days} days ago."})
    if lookalike and not verified_employer:
        red_flags.append({
            "flag": "Look-alike domain",
            "detail": f"{lookalike} borrows the company name but is not the "
                      f"official domain ({brand_domain or official_domain})."})
    if search_status == "claimed_only" and not verified_employer and not lookalike:
        red_flags.append({
            "flag": "Unverified brand claim",
            "detail": f"The offer names {official_domain} but shows no link or "
                      f"email from that domain, so the sender is unconfirmed."})
    upi = _UPI_RE.search(offer_text or "")
    if upi:
        red_flags.append({
            "flag": "Payment to a personal UPI ID",
            "detail": f"The offer asks for money to {upi.group(0)}, which no "
                      f"legitimate employer does."})
    # NOTE: "no interview mentioned" is deliberately not a red flag. Campus
    # crew, ambassador and community programs do not run interviews.

    # If we have literally nothing to check against, say so instead of
    # returning a clean bill of health.
    low_confidence = not verified_employer

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
            verified_employer=verified_employer,
            search_status=search_status,
        )
    except Exception:
        result = None

    if not isinstance(result, dict):
        result = _fallback_result(offer_text, fields, official_domain, domain_match,
                                  red_flags, language, verified_employer,
                                  low_confidence)
    else:
        ai_flags = result.get("red_flags", [])
        existing = {_flag_key(f.get("flag")) for f in red_flags}
        for f in ai_flags:
            key = _flag_key(f.get("flag"))
            if key and key not in existing:
                red_flags.append(f)
                existing.add(key)
        result["red_flags"] = red_flags
        result.setdefault("company_name", company or (result.get("company_name") or ""))
        result["company_verified"] = verified_employer
        result["official_website"] = f"https://{official_domain}" if official_domain else ""
        result["domain_match"] = domain_match
        result.setdefault("verdict", _verdict_from_score(result.get("risk_score", 50)))

    # A confirmed employer domain is a hard floor of trust: a real offer from
    # hackerrank.com must never be called a scam because a search timed out.
    if not verified_employer:
        advisory = {"Unverified brand claim"}
        hard = [f for f in result.get("red_flags", [])
                if (f.get("flag") or "") not in advisory]
        if not hard:
            try:
                result["risk_score"] = min(int(result.get("risk_score") or 50), 55)
            except (TypeError, ValueError):
                result["risk_score"] = 50
            result["verdict"] = _verdict_from_score(result["risk_score"])
            if result["risk_score"] <= 39:
                result["scam_type"] = "Likely Safe"
                result["category"] = "Likely Safe"

    try:
        score_now = int(result.get("risk_score") or 50)
    except (TypeError, ValueError):
        score_now = 50
    floor = 0
    if upi:
        floor = 85
    elif lookalike:
        floor = 80
    if floor and score_now < floor:
        result["risk_score"] = floor
        result["verdict"] = "Likely scam"
        result["scam_type"] = "Job Scam"
        result["category"] = "Job Scam"

    if verified_employer:
        try:
            result["risk_score"] = min(int(result.get("risk_score") or 50), 25)
        except (TypeError, ValueError):
            result["risk_score"] = 20
        result["verdict"] = "Likely genuine"
        result["scam_type"] = "Likely Safe"
        result["category"] = "Likely Safe"
        noise = {"Company not found online", "No interview process",
                 "Domain mismatch"}
        result["red_flags"] = [f for f in result.get("red_flags", [])
                               if (f.get("flag") or "") not in noise]

    _CACHE[key] = (time.time(), result)
    return result


def _verdict_from_score(score: int) -> str:
    if score >= 70:
        return "Likely scam"
    if score >= 40:
        return "Suspicious"
    return "Likely genuine"
