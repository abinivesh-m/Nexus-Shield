# 🛡️ NexusShield

> AI-Powered Digital Public Safety Platform

NexusShield is a full-stack AI-powered cybersecurity platform that helps citizens identify and report digital fraud while providing authorities with actionable intelligence.
It combines Artificial Intelligence, Computer Vision, Natural Language Processing, and Geospatial Intelligence into a single mobile application.

---

## 🚀 Features

### 🤖 AI Scam Detection
- Screenshot Analysis
- Scam Message Detection
- Malicious URL Detection
- Scam Call Analysis
- AI Scam Copilot

### 💵 Counterfeit Currency Detection
- Scan currency using AI
- Authenticity confidence score
- AI-generated reasoning

### 🕸️ Fraud Network Intelligence
- Connects scam reports using
  - Phone Numbers
  - UPI IDs
  - Bank Accounts
  - Device IDs
  - Websites
- Interactive fraud relationship graph

### 🗺️ Crime Hotspot Intelligence
- OpenStreetMap Integration
- Geo-tagged fraud reports
- Interactive hotspot visualization

### 📊 Dashboard & Analytics
- Threat Statistics
- Report History
- Scam Trends
- Administrative Dashboard

---

# 🏗️ System Architecture

```
Flutter App
      │
      ▼
FastAPI Backend
      │
      ▼
Google Gemini AI
      │
      ▼
SQLite / PostgreSQL
      │
      ▼
Fraud Intelligence Dashboard
```

---

# 🛠️ Tech Stack

## Frontend
- Flutter
- Dart
- Provider
- flutter_map (OpenStreetMap)
- fl_chart

## Backend
- FastAPI
- Python
- SQLAlchemy
- JWT Authentication

## AI
- Google Gemini 2.5 Flash
- Gemini Vision API

## Database
- SQLite
- PostgreSQL

## Deployment
- Railway

---

# 📁 Project Structure

```
NexusShield
│
├── frontend/
│   ├── lib/
│   ├── assets/
│   └── pubspec.yaml
│
├── backend/
│   ├── routers/
│   ├── database/
│   ├── models/
│   ├── services/
│   ├── ai_engine.py
│   └── main.py
│
└── README.md
```

---

# ⚙️ Installation

## Clone Repository

```bash
git clone https://github.com/abinivesh-m/Nexus-Shield.git
cd NexusShield
```

## Backend

```bash
cd backend

python -m venv .venv

pip install -r requirements.txt

uvicorn main:app --reload
```

## Frontend

```bash
cd frontend

flutter pub get

flutter run
```

---

# 🔐 Environment Variables

Create a `.env` file inside the backend folder.

```env
GEMINI_API_KEY=YOUR_API_KEY
DATABASE_URL=sqlite:///nexusshield.db
JWT_SECRET=YOUR_SECRET_KEY
```

---

# 🔄 Workflow

1. User submits suspicious content.
2. FastAPI receives the request.
3. Google Gemini AI analyzes the input.
4. Results are stored in the database.
5. Fraud intelligence is updated.
6. Dashboard and hotspot map refresh.
7. User receives a risk score and recommendations.


# 🔮 Future Scope

- Voice Spoofing Detection
- Deepfake Detection
- Real-Time Call Monitoring
- Government Cybercrime Integration
- Multilingual AI Support

---

# 👥 Team

Team NexusAI

---

# 📜 License

This project was developed for educational, research, and hackathon purposes.
