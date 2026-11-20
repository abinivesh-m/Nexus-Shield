# 🌀 NexusShield

> *"Those who break the rules are scum, but those who abandon their friends are worse than scum."* — Obito Uchiha
>
> We apply the same rule to offers: a scam is scum. We catch it before it reaches you.

**AI-powered scam protection for Indian students — with one feature no other checker ships: a verdict you can revoke.** 🛡️

[![CI](https://github.com/abinivesh-m/Nexus-Shield/actions/workflows/build.yml/badge.svg)](https://github.com/abinivesh-m/Nexus-Shield/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.111-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)

---

## 🎯 The Mission

A student pastes an internship or job offer. In seconds they get a **risk score (0–100)**, every red flag explained, and advice on what to do next. The app verifies the company actually exists online, matches the recruiter's email domain, checks domain age, and flags scam patterns — registration fees, unrealistic stipends, look-alike domains, personal UPI IDs.

**The Hokage-level feature — Verified Offer Receipts:** every verification issues an **HMAC-SHA256-signed receipt** (`NS-XXXXXXXXXX`) with a public URL. A placement cell can verify it with no account, no app, no login. If the offer later turns out to be fraud, an admin revokes it — and every receipt for that offer flips to *"Do not proceed."* ⚔️

> Other checkers give an opinion. We give a receipt — one that can be revoked.

## 🥷 Tech Stack (the Jutsu)

| Layer | Jutsu |
|-------|-------|
| Mobile | Flutter (Dart), 5 languages |
| Backend | FastAPI (Python), SQLAlchemy, Pydantic |
| Database | PostgreSQL (Neon) / SQLite (dev) |
| AI | Google Gemini 2.5 Flash |
| Auth | JWT (access + refresh), bcrypt |
| Security | HMAC-SHA256 receipts, rate limiting, CORS, security headers |
| Deploy | Vercel (backend), GitHub Actions (APK CI) |
| Tests | 38 backend tests (unittest), `flutter analyze` 0 errors |

## 🔥 Jutsu List (Features)

- 📸 **9 ways to check** — Screenshot, Message, URL, Copilot, Call transcript, Currency, Hotspot map, Fraud network, Internship verifier
- 🧾 **Verified Offer Receipts** — signed, public, revocable verdicts
- 🔒 **Privacy-first** — consent gate, versioned privacy notice, offer text hashed + redacted, account deletion
- 📊 **Feedback loop** — students report wrong verdicts; admin sees precision / recall / FPR
- 👨‍👩‍👧 **Family protection** — watch over family members' high-risk scans
- 🏢 **Organization dashboard** — multi-user scam exposure monitoring
- 🛟 **Degraded mode** — rule-based fallback when AI is unavailable; never a 500

## ⚡ Quick Start

### Backend
```bash
cd backend
python -m venv venv
venv\Scripts\activate   # Windows
pip install -r requirements.txt
python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

### Flutter app
```bash
flutter pub get
flutter run
```

### Run the tests
```bash
cd backend
python -m unittest discover -s tests
```

## 🗂️ Project Structure

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

## 🌐 Links

- 📱 **Android APK:** [latest release](https://github.com/abinivesh-m/Nexus-Shield/releases/latest)
- 🖥️ **Backend:** https://backend-tau-neon-p94ihvya7x.vercel.app
- ❤️ **Health check:** https://backend-tau-neon-p94ihvya7x.vercel.app/health
- 🧾 **Receipt pages:** every issued receipt gets a public page at `/r/<receipt-id>` — readable by a placement cell with no account, no app, no login.

## 📜 License

MIT — see [LICENSE](LICENSE).

## 👤 Author

**Abinivesh M** — ECE student @ SKCET, Coimbatore
- GitHub: [@abinivesh-m](https://github.com/abinivesh-m)
- LinkedIn: [abinivesh-m](https://www.linkedin.com/in/abinivesh-m-883052380/)
- Email: abinivesh.1203@gmail.com

---

*"A dropout will beat a genius through hard work."* — Rock Lee 🥋
Made with chakra, code, and caffeine. ⚡
