# NexusShield — Production Build

AI-powered scam detection platform for India: Flutter app + FastAPI backend.
This build implements every phase from the original roadmap (Phases 1–10)
as real, working code. Read this file before running anything — it's
honest about what's live out of the box vs. what needs your own API keys.

## What's fully working with zero setup

- **Auth**: email/password signup, login, JWT access + refresh tokens,
  forgot/reset password, email verification, session management
  (list/revoke devices).
- **Profile**: name, photo URL, language, theme, notification & security
  preferences, account deletion.
- **Analysis history**: every scan saved, searchable, deletable, exportable
  (CSV/JSON), grouped into Today/Yesterday/This Week/Earlier.
- **Live scam database**: local SQLite table of known phishing
  domains/URLs, scam phone numbers, and fake UPI IDs, checked *before*
  the AI call — instant match, no AI cost, seeded with realistic
  India-context examples.
- **Scam reporting**: users submit reports (screenshot/website/phone/UPI/
  description); admin review queue; verified reports auto-promote into
  the live scam database.
- **AI explanations**: structured red-flag reasons (not just a risk score),
  scam categories, multi-language output (English, Tamil, Hindi, Kannada,
  Telugu).
- **Clipboard monitor**: in-app check whenever NexusShield regains focus —
  warns about suspicious URLs/UPI IDs/wallet addresses you just copied.
- **Threat feed & news**: seeded India-relevant scam alerts and CERT-In/RBI
  style advisories.
- **Family protection**: link accounts, get alerted when a watched family
  member hits a high-risk scan.
- **Enterprise dashboard**: create an org, invite teammates, see aggregate
  scan stats and per-member risk breakdown.
- **Admin panel**: manage users, review reports, manage the scam database,
  platform-wide analytics. Default demo admin:
  `admin@nexusshield.app` / `ChangeMe123!` — **change this immediately**
  in any real deployment.
- **PDF reports**: generate a formatted incident report per scan, suitable
  for attaching to a cybercrime.gov.in complaint.
- **Personal dashboard & analytics**: today's scans, weekly trend chart,
  safe/suspicious/risky breakdown, most common scam type.
- **Dark/light theme toggle**, glassmorphism cards, animations — all from
  the original prototype, extended consistently.

## What needs your own credentials before it's "real"

These are built as clean, working integration points — not fake demos —
but they need keys/infra I can't provision on your behalf:

| Feature | What's stubbed | To go live |
|---|---|---|
| Google/Apple Sign-In | Backend trusts the client-supplied OAuth payload as-is | Get real client IDs, verify `id_token` server-side against Google/Apple's public keys before trusting the email claim (see `backend/app/routers/auth_router.py`) |
| Push notifications | Notifications are saved to a DB table the app polls; no real push | Set up Firebase Cloud Messaging, store device tokens, swap the `print()` in `backend/app/push_stub.py` for a real `messaging.send()` call |
| Safe Browsing / VirusTotal / AbuseIPDB / HIBP | Each returns `"not_configured"` until its API key is set | Add keys to `backend/.env` (see `.env.example`); `backend/app/integrations.py` already calls the real APIs once a key is present |
| SMS/Call interception | Not implemented | Needs a native Android foreground service + runtime permissions + Play Store policy review — out of scope for a cross-platform Flutter widget |
| CI/CD, Postgres, monitoring | Uses local SQLite | Point `DATABASE_URL` at Postgres; the schema is portable (no SQLite-only types) |

## Running the backend

```bash
cd backend
pip install -r requirements.txt
cp .env.example .env   # then fill in GEMINI_API_KEY at minimum
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

First run auto-creates `backend/data/nexusshield.db` (SQLite) and seeds the
scam database, threat feed, news, and the demo admin account.

## Running the Flutter app

```bash
flutter pub get
flutter run
```

In `lib/services/api_service.dart`, `_BASE_URL` defaults to
`http://10.0.2.2:8000` (Android emulator → host machine). For a physical
device on the same network, change it to your machine's LAN IP; for a
deployed backend, point it at that URL.

## Architecture

```
Flutter App (lib/)
  ├── screens/        feature screens (auth, profile, history, reports,
  │                   family, org, admin, intel, dashboard, ...)
  ├── services/        ApiService — single HTTP client, handles auth + refresh
  ├── models/          typed response models
  └── widgets/         shared UI (risk meter, clipboard monitor)

FastAPI Backend (backend/)
  ├── main.py          wires all routers together
  └── app/
      ├── models.py     SQLAlchemy ORM (users, history, reports, scam DB, ...)
      ├── routers/      one file per feature area
      ├── ai_engine.py  Gemini API wrapper (categories, languages, structured output)
      ├── scam_db.py    local scam-database matching (Phase 1.5)
      ├── integrations.py  external API clients (Safe Browsing, VirusTotal, ...)
      ├── report_pdf.py PDF generation (reportlab)
      └── push_stub.py  notification dispatch — swap in real FCM here
```
