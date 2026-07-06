"""
NexusShield FastAPI Backend — Production-shaped build.

Run: uvicorn main:app --reload --host 0.0.0.0 --port 8000

Covers Phases 1-10 from the roadmap:
  /auth/*           Phase 1 - Authentication
  /profile/*        Phase 1 - User Profile
  /history/*        Phase 1 - Analysis History
  /reports/*        Phase 1 & 6 - Scam Reporting + PDF reports
  /analyze/*        Phase 1.5 & 2 - Live Scam DB + AI analysis + explanations
  /copilot/*        AI Copilot chat
  /categories       Phase 2 - Scam categories + supported languages
  /family/*         Phase 5 - Family Protection
  /org/*            Phase 5 - Enterprise/Organization Dashboard
  /admin/*          Phase 5 - Admin Panel
  /intel/*          Phase 4 - Threat Feed & News
  /notifications/*  Phase 9 - Notifications
  /dashboard/*      Phase 4 & 10 - Dashboard + Personal Analytics
  /integrations/*   Phase 7 - External Integrations (Safe Browsing, VirusTotal, AbuseIPDB, HIBP)

Uses SQLite by default so the whole stack runs with zero external services.
Set DATABASE_URL to point at Postgres for production (see app/database.py).
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Anchor to this file's directory rather than relying on the process's
# current working directory -- uvicorn's --reload spawns a subprocess that
# can start from a different cwd (notably on Windows), which silently makes
# a cwd-relative load_dotenv() find nothing.
load_dotenv(dotenv_path=Path(__file__).resolve().parent / ".env")

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import init_db, SessionLocal
from app.seed_data import seed_if_empty

from app.routers import (
    auth_router, profile_router, history_router, reports_router,
    analysis_router, family_router, org_router, admin_router,
    intel_router, notifications_router, dashboard_router,
    report_pdf_router, integrations_router, currency_router,
)

app = FastAPI(title="NexusShield API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    init_db()
    db = SessionLocal()
    try:
        seed_if_empty(db)
    finally:
        db.close()


app.include_router(auth_router.router)
app.include_router(profile_router.router)
app.include_router(history_router.router)
app.include_router(reports_router.router)
app.include_router(report_pdf_router.router)
app.include_router(analysis_router.router)
app.include_router(family_router.router)
app.include_router(org_router.router)
app.include_router(admin_router.router)
app.include_router(intel_router.router)
app.include_router(notifications_router.router)
app.include_router(dashboard_router.router)
app.include_router(integrations_router.router)
app.include_router(currency_router.router)


@app.get("/")
async def root():
    """Root endpoint — API info and available endpoints."""
    return {
        "status": "online",
        "service": "NexusShield API",
        "version": "2.0.0",
        "message": "NexusShield — AI-powered scam detection and threat intelligence",
        "docs": "/docs",
        "openapi": "/openapi.json",
        "endpoints": {
            "auth": "/auth/*",
            "profile": "/profile/*",
            "history": "/history/*",
            "reports": "/reports/*",
            "analysis": "/analyze/*",
            "family": "/family/*",
            "organization": "/org/*",
            "admin": "/admin/*",
            "intelligence": "/intel/*",
            "notifications": "/notifications/*",
            "dashboard": "/dashboard/*",
            "integrations": "/integrations/*",
        },
        "health": "/health",
    }


@app.get("/health")
async def health():
    return {"status": "ok", "service": "NexusShield API", "version": "2.0.0"}
