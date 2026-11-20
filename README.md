# NexusShield

> AI-powered scam protection for Indian students — with one feature no other checker ships: a verdict you can revoke.

[![CI](https://github.com/abinivesh-m/Nexus-Shield/actions/workflows/build.yml/badge.svg)](https://github.com/abinivesh-m/Nexus-Shield/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## What it does

A student pastes an internship/job offer and gets a risk score (0-100), red flags, and advice in seconds. The app verifies the company exists online, matches the recruiter email domain, checks domain age, and flags scam patterns (registration fees, unrealistic stipends, look-alike domains, personal UPI IDs).

**Unique feature — Verified Offer Receipts:** Every verification issues an HMAC-SHA256-signed receipt (NS-XXXXXXXXXX) with a public URL. A placement cell can verify it without an account. If the offer later turns out to be fraud, an admin revokes it — and every receipt for that offer flips to "Do not proceed."

## Tech stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter (Dart), 5 languages |
| Backend | FastAPI (Python), SQLAlchemy, Pydantic |
| Database | PostgreSQL (Neon) / SQLite (dev) |
| AI | Google Gemini 2.5 Flash |
| Auth | JWT (access + refresh), bcrypt |
| Security | HMAC-SHA256 receipts, rate limiting, CORS, security headers |
| Deploy | Vercel (backend), GitHub Actions (APK CI) |
| Testing | 38 backend tests (unittest), flutter analyze 0 errors |

## Features

- **9 ways to check:** Screenshot, Message, URL, Copilot, Call transcript, Currency, Hotspot map, Fraud network, Internship verifier
- **Verified Offer Receipts:** Signed, public, revocable verdicts
- **Privacy-first:** Consent gate, versioned privacy notice, offer text hashed + redacted, account deletion
- **Feedback loop:** Students report wrong verdicts; admin sees precision/recall/FPR
- **Family protection:** Watch over family members' high-risk scans
- **Organization dashboard:** Multi-user scam exposure monitoring
- **Degraded mode:** Rule-based fallback when AI is unavailable — never a 500

## Install

Grab the signed release APK from the [latest release](https://github.com/abinivesh-m/Nexus-Shield/releases/latest) and sideload it on Android 8+. The backend it talks to is already deployed, so no setup is needed to try it.

## Quick start

### Backend
```bash
cd backend
python -m venv venv
venv\Scripts\activate  # Windows
pip install -r requirements.txt
python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

### Flutter app
```bash
flutter pub get
flutter run
```

### Run tests
```bash
cd backend
python -m unittest discover -s tests
```

## Project structure

```
nexusshield/
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI app, middleware, startup
│   │   ├── auth.py              # JWT + password hashing
│   │   ├── models.py            # SQLAlchemy models
│   │   ├── schemas.py           # Pydantic schemas
│   │   ├── receipts.py          # HMAC receipt signing/verification
│   │   ├── internship_verifier.py # Offer verification logic
│   │   ├── ai_engine.py         # Gemini AI wrapper
│   │   └── routers/             # API endpoints
│   └── tests/                   # 38 backend tests
├── lib/
│   ├── screens/                 # Flutter UI screens
│   ├── services/                # API service layer
│   ├── models/                  # Dart data models
│   └── widgets/                 # Reusable UI components
├── docs/
│   ├── UNIQUENESS.md            # Investor-ready uniqueness answer
│   ├── PRIVACY.md               # Privacy notice
│   └── SECURITY.md              # Security documentation
└── .github/workflows/           # CI/CD (APK build)
```

## Live links

- **Android APK:** https://github.com/abinivesh-m/Nexus-Shield/releases/latest
- **Backend:** https://backend-tau-neon-p94ihvya7x.vercel.app
- **Health check:** https://backend-tau-neon-p94ihvya7x.vercel.app/health
- **Receipt pages:** every issued receipt gets a public page at `/r/<receipt-id>` — readable by a placement cell with no account, no app, no login.

## License

MIT — see [LICENSE](LICENSE).

## Author

**Abinivesh M** — ECE student @ SKCET, Coimbatore
- GitHub: [@abinivesh-m](https://github.com/abinivesh-m)
- LinkedIn: [abinivesh-m](https://www.linkedin.com/in/abinivesh-m-883052380/)
- Email: abinivesh.1203@gmail.com
