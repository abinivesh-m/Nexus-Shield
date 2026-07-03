"""
Phase 1 — Authentication.

Email/password, Google/Apple OAuth (token-verification stubbed — wire in
google-auth / Apple's JWKS verification once you have real client IDs),
forgot password, email verification, and session management via
refresh tokens that can be individually revoked.
"""
import datetime as dt

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session as DBSession

from ..database import get_db
from .. import models, schemas
from ..auth import (
    hash_password, verify_password, create_access_token,
    generate_refresh_token, generate_email_token,
)
from ..deps import get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])

REFRESH_TOKEN_DAYS = 30
EMAIL_TOKEN_HOURS = 24


def _issue_tokens(db: DBSession, user: models.User, device_label: str) -> schemas.AuthTokens:
    refresh_token = generate_refresh_token()
    session = models.Session(user_id=user.id, refresh_token=refresh_token, device_label=device_label)
    db.add(session)
    user.last_login_at = dt.datetime.utcnow()
    db.commit()
    access_token = create_access_token(user.id, extra={"is_admin": user.is_admin})
    return schemas.AuthTokens(access_token=access_token, refresh_token=refresh_token)


@router.post("/signup", response_model=schemas.AuthTokens)
def signup(req: schemas.SignupRequest, db: DBSession = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.email == req.email).first()
    if existing:
        raise HTTPException(status_code=409, detail="An account with this email already exists")

    user = models.User(
        email=req.email,
        password_hash=hash_password(req.password),
        name=req.name or req.email.split("@")[0],
    )
    db.add(user)
    db.commit()

    # Issue an email verification token (in production: send via email provider)
    token = generate_email_token()
    db.add(models.EmailToken(
        user_id=user.id, token=token, kind="verify",
        expires_at=dt.datetime.utcnow() + dt.timedelta(hours=EMAIL_TOKEN_HOURS),
    ))
    db.commit()

    return _issue_tokens(db, user, "Signup device")


@router.post("/login", response_model=schemas.AuthTokens)
def login(req: schemas.LoginRequest, db: DBSession = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == req.email).first()
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return _issue_tokens(db, user, req.device_label)


@router.post("/oauth", response_model=schemas.AuthTokens)
def oauth_login(req: schemas.OAuthLoginRequest, db: DBSession = Depends(get_db)):
    """
    Google/Apple sign-in.

    NOTE: this trusts the client-supplied id_token's claims directly, which
    is fine for local demo use. In production, verify `id_token` server-side
    against Google's tokeninfo endpoint or Apple's public JWKS before
    trusting `email`/`name` — do not skip that step with real credentials.
    """
    if req.provider not in ("google", "apple"):
        raise HTTPException(status_code=400, detail="Unsupported provider")

    user = db.query(models.User).filter(models.User.email == req.email).first()
    if not user:
        user = models.User(
            email=req.email,
            name=req.name or req.email.split("@")[0],
            photo_url=req.photo_url,
            auth_provider=req.provider,
            is_email_verified=True,  # OAuth providers verify email themselves
        )
        db.add(user)
        db.commit()

    return _issue_tokens(db, user, req.device_label)


@router.post("/refresh", response_model=schemas.AuthTokens)
def refresh(req: schemas.RefreshRequest, db: DBSession = Depends(get_db)):
    session = db.query(models.Session).filter(
        models.Session.refresh_token == req.refresh_token,
        models.Session.revoked == False,  # noqa: E712
    ).first()
    if not session:
        raise HTTPException(status_code=401, detail="Invalid or revoked refresh token")

    user = db.query(models.User).filter(models.User.id == session.user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    session.last_active_at = dt.datetime.utcnow()
    db.commit()
    access_token = create_access_token(user.id, extra={"is_admin": user.is_admin})
    return schemas.AuthTokens(access_token=access_token, refresh_token=req.refresh_token)


@router.post("/forgot-password")
def forgot_password(req: schemas.ForgotPasswordRequest, db: DBSession = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == req.email).first()
    # Always return 200 regardless of whether the email exists, to avoid
    # leaking which emails are registered.
    if user:
        token = generate_email_token()
        db.add(models.EmailToken(
            user_id=user.id, token=token, kind="reset",
            expires_at=dt.datetime.utcnow() + dt.timedelta(hours=2),
        ))
        db.commit()
        # In production: send `token` via email provider (SendGrid/SES/etc).
        # Returned here only because there is no email provider wired up yet.
        return {"message": "If that email exists, a reset link has been sent.", "dev_reset_token": token}
    return {"message": "If that email exists, a reset link has been sent."}


@router.post("/reset-password")
def reset_password(req: schemas.ResetPasswordRequest, db: DBSession = Depends(get_db)):
    et = db.query(models.EmailToken).filter(
        models.EmailToken.token == req.token,
        models.EmailToken.kind == "reset",
        models.EmailToken.used == False,  # noqa: E712
    ).first()
    if not et or et.expires_at < dt.datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")

    user = db.query(models.User).filter(models.User.id == et.user_id).first()
    user.password_hash = hash_password(req.new_password)
    et.used = True
    db.commit()
    return {"message": "Password updated successfully"}


@router.post("/send-verification")
def send_verification(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    if user.is_email_verified:
        return {"message": "Email already verified"}
    token = generate_email_token()
    db.add(models.EmailToken(
        user_id=user.id, token=token, kind="verify",
        expires_at=dt.datetime.utcnow() + dt.timedelta(hours=EMAIL_TOKEN_HOURS),
    ))
    db.commit()
    return {"message": "Verification email sent", "dev_verify_token": token}


@router.post("/verify-email")
def verify_email(req: schemas.VerifyEmailRequest, db: DBSession = Depends(get_db)):
    et = db.query(models.EmailToken).filter(
        models.EmailToken.token == req.token,
        models.EmailToken.kind == "verify",
        models.EmailToken.used == False,  # noqa: E712
    ).first()
    if not et or et.expires_at < dt.datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invalid or expired verification token")

    user = db.query(models.User).filter(models.User.id == et.user_id).first()
    user.is_email_verified = True
    et.used = True
    db.commit()
    return {"message": "Email verified successfully"}


@router.get("/sessions")
def list_sessions(user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    sessions = db.query(models.Session).filter(
        models.Session.user_id == user.id, models.Session.revoked == False  # noqa: E712
    ).order_by(models.Session.last_active_at.desc()).all()
    return [
        {
            "id": s.id, "device_label": s.device_label,
            "created_at": s.created_at, "last_active_at": s.last_active_at,
        }
        for s in sessions
    ]


@router.delete("/sessions/{session_id}")
def revoke_session(session_id: str, user: models.User = Depends(get_current_user), db: DBSession = Depends(get_db)):
    session = db.query(models.Session).filter(
        models.Session.id == session_id, models.Session.user_id == user.id
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    session.revoked = True
    db.commit()
    return {"message": "Session revoked"}


@router.post("/logout")
def logout(req: schemas.RefreshRequest, db: DBSession = Depends(get_db)):
    session = db.query(models.Session).filter(models.Session.refresh_token == req.refresh_token).first()
    if session:
        session.revoked = True
        db.commit()
    return {"message": "Logged out"}
