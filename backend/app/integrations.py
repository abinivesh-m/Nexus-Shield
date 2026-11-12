"""
Phase 7 — External Integrations.

Each function checks for its API key in the environment and, if present,
calls the real service; if absent, it returns a clearly-marked
'not_configured' result so the rest of the app can degrade gracefully
instead of crashing. This means the app is honest about what's real vs.
mocked at runtime rather than silently faking data.

To go live, set these environment variables:
  GOOGLE_SAFE_BROWSING_API_KEY
  VIRUSTOTAL_API_KEY
  ABUSEIPDB_API_KEY
  HIBP_API_KEY

NOTE: this module makes outbound HTTPS calls to third-party services.
Network egress must be enabled in whatever environment runs the backend.
"""
import os
import httpx

GOOGLE_SAFE_BROWSING_API_KEY = os.environ.get("GOOGLE_SAFE_BROWSING_API_KEY", "")
VIRUSTOTAL_API_KEY = os.environ.get("VIRUSTOTAL_API_KEY", "")
ABUSEIPDB_API_KEY = os.environ.get("ABUSEIPDB_API_KEY", "")
HIBP_API_KEY = os.environ.get("HIBP_API_KEY", "")

TIMEOUT = 8.0


def _not_configured(provider: str) -> dict:
    return {"provider": provider, "status": "not_configured", "detail": f"Set the {provider} API key to enable this check."}


async def check_safe_browsing(url: str) -> dict:
    if not GOOGLE_SAFE_BROWSING_API_KEY:
        return _not_configured("GOOGLE_SAFE_BROWSING_API_KEY")
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            resp = await client.post(
                f"https://safebrowsing.googleapis.com/v4/threatMatches:find?key={GOOGLE_SAFE_BROWSING_API_KEY}",
                json={
                    "client": {"clientId": "nexusshield", "clientVersion": "1.0.0"},
                    "threatInfo": {
                        "threatTypes": ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE"],
                        "platformTypes": ["ANY_PLATFORM"],
                        "threatEntryTypes": ["URL"],
                        "threatEntries": [{"url": url}],
                    },
                },
            )
            data = resp.json()
            matches = data.get("matches", [])
            return {"provider": "safe_browsing", "status": "ok", "is_threat": bool(matches), "matches": matches}
    except Exception as e:
        return {"provider": "safe_browsing", "status": "error", "detail": str(e)}


async def check_virustotal(url: str) -> dict:
    if not VIRUSTOTAL_API_KEY:
        return _not_configured("VIRUSTOTAL_API_KEY")
    try:
        import base64
        url_id = base64.urlsafe_b64encode(url.encode()).decode().strip("=")
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            resp = await client.get(
                f"https://www.virustotal.com/api/v3/urls/{url_id}",
                headers={"x-apikey": VIRUSTOTAL_API_KEY},
            )
            if resp.status_code == 404:
                return {"provider": "virustotal", "status": "ok", "is_threat": False, "detail": "Not previously analyzed"}
            data = resp.json()
            stats = data.get("data", {}).get("attributes", {}).get("last_analysis_stats", {})
            malicious = stats.get("malicious", 0) + stats.get("suspicious", 0)
            return {"provider": "virustotal", "status": "ok", "is_threat": malicious > 0, "stats": stats}
    except Exception as e:
        return {"provider": "virustotal", "status": "error", "detail": str(e)}


async def check_abuseipdb(ip: str) -> dict:
    if not ABUSEIPDB_API_KEY:
        return _not_configured("ABUSEIPDB_API_KEY")
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            resp = await client.get(
                "https://api.abuseipdb.com/api/v2/check",
                params={"ipAddress": ip, "maxAgeInDays": 90},
                headers={"Key": ABUSEIPDB_API_KEY, "Accept": "application/json"},
            )
            data = resp.json().get("data", {})
            score = data.get("abuseConfidenceScore", 0)
            return {"provider": "abuseipdb", "status": "ok", "is_threat": score >= 50, "abuse_score": score}
    except Exception as e:
        return {"provider": "abuseipdb", "status": "error", "detail": str(e)}


async def check_hibp(email: str) -> dict:
    if not HIBP_API_KEY:
        return _not_configured("HIBP_API_KEY")
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT) as client:
            resp = await client.get(
                f"https://haveibeenpwned.com/api/v3/breachedaccount/{email}",
                headers={"hibp-api-key": HIBP_API_KEY},
            )
            if resp.status_code == 404:
                return {"provider": "hibp", "status": "ok", "breached": False, "breaches": []}
            breaches = resp.json()
            return {"provider": "hibp", "status": "ok", "breached": True, "breaches": [b.get("Name") for b in breaches]}
    except Exception as e:
        return {"provider": "hibp", "status": "error", "detail": str(e)}


async def enrich_url(url: str) -> dict:
    """Run all relevant URL-based checks concurrently."""
    import asyncio
    safe_browsing, virustotal = await asyncio.gather(
        check_safe_browsing(url), check_virustotal(url)
    )
    return {"safe_browsing": safe_browsing, "virustotal": virustotal}
