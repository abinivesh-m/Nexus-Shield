"""
Auth utilities: password hashing + JWT access/refresh tokens.

For the demo this uses a local HS256 secret. In production, set
JWT_SECRET via environment variable and rotate it through a secrets
manager — never commit a real secret.
"""
import os
import datetime as dt
import secrets

import jwt
from passlib.context import CryptContext

_IS_PROD = (
    os.environ.get("VERCEL_ENV") == "production"
    or os.environ.get("ENV", "").lower() == "production"
)

# Fail closed in production: a missing secret must not silently fall back to a
# well-known string that anyone can use to forge tokens.
_DEFAULT_JWT = "nexusshield-dev-secret-change-me"
_env_jwt = os.environ.get("JWT_SECRET")
if _env_jwt:
    JWT_SECRET = _env_jwt
elif _IS_PROD:
    raise RuntimeError("JWT_SECRET must be set in production")
else:
    JWT_SECRET = _DEFAULT_JWT

JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_MINUTES = 30
REFRESH_TOKEN_DAYS = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    return pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    if not hashed:
        return False
    try:
        return pwd_context.verify(plain, hashed)
    except Exception:
        return False


def create_access_token(user_id: str, extra: dict | None = None) -> str:
    payload = {
        "sub": user_id,
        "type": "access",
        "exp": dt.datetime.utcnow() + dt.timedelta(minutes=ACCESS_TOKEN_MINUTES),
        "iat": dt.datetime.utcnow(),
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> dict | None:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "access":
            return None
        return payload
    except jwt.PyJWTError:
        return None


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def generate_email_token() -> str:
    return secrets.token_urlsafe(32)
