"""Phase 7 — External Integrations endpoints."""
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from .. import models
from ..deps import get_current_user
from .. import integrations

router = APIRouter(prefix="/integrations", tags=["integrations"])


class UrlCheckBody(BaseModel):
    url: str


class EmailCheckBody(BaseModel):
    email: str


@router.post("/check-url")
async def check_url_enrichment(body: UrlCheckBody, user: models.User = Depends(get_current_user)):
    return await integrations.enrich_url(body.url)


@router.post("/check-breach")
async def check_breach(body: EmailCheckBody, user: models.User = Depends(get_current_user)):
    return await integrations.check_hibp(body.email)


@router.get("/status")
def integration_status():
    """Lets the app show which external integrations are live vs. not configured."""
    return {
        "google_safe_browsing": bool(integrations.GOOGLE_SAFE_BROWSING_API_KEY),
        "virustotal": bool(integrations.VIRUSTOTAL_API_KEY),
        "abuseipdb": bool(integrations.ABUSEIPDB_API_KEY),
        "hibp": bool(integrations.HIBP_API_KEY),
    }
