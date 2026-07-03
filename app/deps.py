"""FastAPI dependencies for authenticated routes."""
from fastapi import Depends, HTTPException, Header
from sqlalchemy.orm import Session as DBSession

from .database import get_db
from .auth import decode_access_token
from . import models


def get_current_user(
    authorization: str | None = Header(default=None),
    db: DBSession = Depends(get_db),
) -> models.User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")

    token = authorization.split(" ", 1)[1].strip()
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user = db.query(models.User).filter(models.User.id == payload["sub"]).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user


def get_current_admin(user: models.User = Depends(get_current_user)) -> models.User:
    if not user.is_admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return user


def get_optional_user(
    authorization: str | None = Header(default=None),
    db: DBSession = Depends(get_db),
) -> models.User | None:
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    token = authorization.split(" ", 1)[1].strip()
    payload = decode_access_token(token)
    if not payload:
        return None
    return db.query(models.User).filter(models.User.id == payload["sub"]).first()
