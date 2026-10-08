"""
Database configuration.
- Local dev: SQLite (zero config, auto-created)
- Production (Railway/Render): set DATABASE_URL to postgres://... in env vars
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

_DATABASE_URL = os.environ.get("DATABASE_URL", "")

# Railway gives postgres:// but SQLAlchemy needs postgresql://
if _DATABASE_URL.startswith("postgres://"):
    _DATABASE_URL = _DATABASE_URL.replace("postgres://", "postgresql://", 1)

if not _DATABASE_URL:
    # Local dev — use SQLite next to main.py
    import pathlib
    if os.environ.get("VERCEL"):
        # Vercel's filesystem is read-only except /tmp (and /tmp is wiped
        # between cold starts) -- set DATABASE_URL to Postgres for real data.
        _db_path = pathlib.Path("/tmp") / "nexusshield.db"
    else:
        _db_path = pathlib.Path(__file__).resolve().parent.parent / "nexusshield.db"
    _DATABASE_URL = f"sqlite:///{_db_path}"
    _connect_args = {"check_same_thread": False}
else:
    _connect_args = {}

engine = create_engine(
    _DATABASE_URL,
    connect_args=_connect_args,
    pool_pre_ping=True,  # serverless instances sit idle; drop stale connections
)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
Base = declarative_base()


def init_db():
    from . import models  # noqa: F401 — registers all models
    Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
