# 🛡️ NexusShield

> AI-powered scam detection platform for India — Flutter app + FastAPI backend.

[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.111-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Gemini](https://img.shields.io/badge/Google_Gemini-2.5_Flash-4285F4?logo=google&logoColor=white)](https://ai.google.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

NexusShield helps Indian users detect **scams, fraud, and cybercrime** across screenshots, messages, URLs, phone calls, currency notes, and internship offers — with AI explanations in 5 Indian languages. Built for a college launch (SKCET, 5,000+ students) and designed to scale to the broader market.

---

## ✨ Highlights

- **Multi-modal AI analysis** — screenshots, text, URLs, call transcripts, currency photos, internship offers.
- **Live scam database** — instant deterministic matches against known-bad domains/phones/UPI IDs before any AI call.
- **Internship Offer Verifier** — verifies the company exists online, matches recruiter email domain, checks WHOIS domain age, flags red flags. The college-launch wedge.
- **Digital Arrest scam detection** — special prompt + keyword patterns for India's #1 phone scam.
- **Family protection** — guardians get alerted when a watched member hits a high-risk scan.
- **Enterprise dashboard** — org-level aggregate stats and per-member risk breakdown.
- **Admin panel** — user management, report review queue, scam DB management, platform analytics.
- **Multi-language** — English, Tamil, Hindi, Kannada, Telugu.
- **Security-first** — JWT + bcrypt, server-side Google OAuth verification, per-user data isolation, rate limiting, CORS lockdown, security headers.

---

## 🏗️ Architecture

```
┌─────────────────────────┐         ┌─────────────────────────────┐
│  Flutter App (lib/)     │  HTTPS  │  FastAPI Backend (backend/) │
│  ├── screens/           │ ──────► │  ├── main.py (routers)      │
│  ├── services/          │         │  ├── app/ai_engine.py       │
│  ├── models/            │         │  ├── app/scam_db.py         │
│  └── widgets/           │         │  ├── app/internship_*.py    │
└─────────────────────────┘         │  └── app/routers/*          │
                                    └──────────────┬──────────────┘
                                                   │
                                    ┌──────────────┴──────────────┐
                                    │  Neon Postgres (free)        │
                                    │  Google Gemini 2.5 Flash     │
                                    └─────────────────────────────┘
```

---

## 🚀 Features

### Analysis
| Feature | Endpoint | Description |
|---|---|---|
| Screenshot scan | `POST /analyze/screenshot` | OCR-free Gemini Vision scan of any screenshot |
| Text scan | `POST /analyze/text` | Paste SMS/WhatsApp/email text |
| URL check | `POST /analyze/url` | Domain, resolvability, suspicious patterns + AI |
| Scam call detector | `POST /analyze/call` | Digital-arrest pattern detection on transcripts |
| Currency scanner | `POST /analyze/currency` | Counterfeit banknote photo assessment |
| Internship verifier | `POST /analyze/internship` | Company verification + domain match + WHOIS + red flags |
| Clipboard check | `POST /analyze/clipboard` | Instant known-scam match on copied content |

### Platform
- **Auth** — email/password, Google OAuth (server-verified), JWT access + refresh tokens, session/device management, forgot/reset password, email verification.
- **History** — every scan saved, searchable, deletable, CSV/JSON export, grouped by date.
- **Scam reporting** — users submit reports; admin review queue; verified reports auto-promote into the live scam DB.
- **Family protection** — link accounts, risk-threshold alerts.
- **Enterprise dashboard** — org creation, invites, aggregate stats, per-member breakdown.
- **Admin panel** — user management, report review, scam DB CRUD, platform analytics.
- **Threat feed & news** — seeded India-relevant advisories (CERT-In / RBI style).
- **PDF reports** — formatted incident reports for cybercrime.gov.in complaints.
- **Personal analytics** — today's scans, weekly trend, safe/suspicious/risky breakdown.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter 3.44 (Dart) |
| Backend | FastAPI 0.111 (Python 3.11+) |
| Database | SQLite (dev) / PostgreSQL via Neon (prod) |
| AI | Google Gemini 2.5 Flash |
| Auth | JWT (PyJWT) + bcrypt + Google OAuth |
| PDF | ReportLab |
| Hosting | Vercel (backend) + Neon (DB) |
| CI/CD | GitHub Actions (APK build) |

---

## 📦 Getting Started

### Prerequisites
- Python 3.11+
- Flutter 3.44+ (for the app)
- A Google Gemini API key (free at https://aistudio.google.com/apikey)

### Backend

```bash
cd backend
pip install -r requirements.txt
cp .env.example .env   # then fill in GEMINI_API_KEY at minimum
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

First run auto-creates the SQLite DB, seeds the scam database, threat feed, news, and a demo admin account.

- **Swagger docs:** http://localhost:8000/docs
- **Health check:** http://localhost:8000/health
- **Demo admin:** `admin@nexusshield.app` / `ChangeMe123!` (change immediately in production)

### Flutter app

```bash
flutter pub get
flutter run
```

In `lib/services/api_service.dart`, `_BASE_URL` defaults to `http://10.0.2.2:8000` (Android emulator → host). For a physical device, use your machine's LAN IP; for production, point at the deployed backend.

### Environment variables

See `backend/.env.example`. Minimum required: `GEMINI_API_KEY` and `JWT_SECRET`. Everything else degrades gracefully.

---

## 🌐 Deployment (free tier)

### Backend → Vercel + Neon Postgres
1. Create a free Postgres DB at [neon.tech](https://neon.tech) → copy the connection string.
2. Set env vars in Vercel dashboard: `GEMINI_API_KEY`, `JWT_SECRET`, `DATABASE_URL` (Neon string).
3. Deploy: `cd backend && vercel --prod --yes`
4. Health check: `https://<your-app>.vercel.app/health`

### Frontend → APK via GitHub Actions
Push to `main` → the workflow in `.github/workflows/build-apk.yml` builds the APK automatically. Download from **Actions → Artifacts**.

Or build locally (requires Android SDK):
```bash
flutter pub get
flutter build apk --release
```

---

## 🔒 Security

See [SECURITY.md](SECURITY.md) for the full security overview. Highlights:

- JWT authentication with bcrypt password hashing
- Google OAuth verified server-side against Google's tokeninfo endpoint
- Per-user data isolation (verified by tests)
- Rate limiting (60 req/60s per IP)
- CORS restricted to known origins
- Security headers (HSTS, X-Frame-Options, nosniff)
- Secrets in environment variables, never in source
- HTTPS everywhere in production

---

## 📁 Project Structure

```
nexusshield/
├── lib/                    # Flutter app
│   ├── main.dart           # App shell, theme, navigation
│   ├── screens/            # Feature screens
│   ├── services/           # ApiService (HTTP client)
│   ├── models/             # Typed response models
│   └── widgets/            # Shared UI components
├── backend/                # FastAPI backend
│   ├── main.py             # App entry, router wiring
│   ├── app/
│   │   ├── models.py       # SQLAlchemy ORM
│   │   ├── schemas.py      # Pydantic request/response
│   │   ├── ai_engine.py    # Gemini wrapper
│   │   ├── scam_db.py      # Live scam DB matching
│   │   ├── internship_verifier.py  # Offer verification pipeline
│   │   ├── integrations.py # Safe Browsing, VirusTotal, etc.
│   │   └── routers/        # One file per feature area
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .env.example
├── .github/workflows/      # CI/CD (APK build)
├── SECURITY.md
└── README.md
```

---

## 🤝 Contributing

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure `flutter analyze` and `flutter test` pass before submitting.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgements

- Google Gemini for the AI backbone
- FastAPI and Flutter teams
- SKCET (Sri Krishna College of Engineering and Technology) for the launch context
- CERT-In and RBI for public scam advisories that informed the seed data

---

<p align="center">
  Built with ❤️ for India's digital safety
</p>
