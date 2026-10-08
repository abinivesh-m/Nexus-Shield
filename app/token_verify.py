"""
Server-side verification of sign-in tokens sent by the Flutter app.

Accepts either:
  * a Firebase ID token  (FirebaseAuth.instance.currentUser.getIdToken())
    -> audience must equal FIREBASE_PROJECT_ID
  * a Google ID token    (GoogleSignInAuthentication.idToken)
    -> audience must be one of GOOGLE_OAUTH_CLIENT_ID (comma-separated) or a
       client ID belonging to GOOGLE_PROJECT_NUMBER (IDs start "<number>-")

Signatures are checked against Google's public keys, so no service-account
file is needed. If none of the env vars are set, verification is skipped
for local development only (never on Vercel).
"""
import os

import requests
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

_session = requests.Session()
_request = google_requests.Request(session=_session)

FIREBASE_PROJECT_ID = os.environ.get("FIREBASE_PROJECT_ID", "").strip()
GOOGLE_PROJECT_NUMBER = os.environ.get("GOOGLE_PROJECT_NUMBER", "").strip()
GOOGLE_CLIENT_IDS = {
    c.strip() for c in os.environ.get("GOOGLE_OAUTH_CLIENT_ID", "").split(",") if c.strip()
}

GOOGLE_ISSUERS = {"accounts.google.com", "https://accounts.google.com"}


class TokenError(Exception):
    pass


def verification_configured() -> bool:
    return bool(FIREBASE_PROJECT_ID or GOOGLE_PROJECT_NUMBER or GOOGLE_CLIENT_IDS)


def verification_required() -> bool:
    return verification_configured() or bool(os.environ.get("VERCEL"))


def _google_aud_ok(aud: str) -> bool:
    if aud in GOOGLE_CLIENT_IDS:
        return True
    return bool(GOOGLE_PROJECT_NUMBER) and aud.startswith(f"{GOOGLE_PROJECT_NUMBER}-")


def verify_signin_token(token: str) -> dict:
    """Return verified claims (email, name, picture, ...) or raise TokenError."""
    if not token:
        raise TokenError("Missing id_token")
    if not verification_configured():
        raise TokenError("Sign-in verification is not configured on the server")

    errors = []

    if FIREBASE_PROJECT_ID:
        try:
            claims = google_id_token.verify_firebase_token(
                token, _request, audience=FIREBASE_PROJECT_ID
            )
            if claims.get("iss") != f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}":
                raise ValueError("wrong issuer")
            return claims
        except Exception as e:  # noqa: BLE001
            errors.append(f"firebase: {e}")

    if GOOGLE_CLIENT_IDS or GOOGLE_PROJECT_NUMBER:
        try:
            # audience checked manually so multiple client IDs are allowed
            claims = google_id_token.verify_oauth2_token(token, _request, audience=None)
            if claims.get("iss") not in GOOGLE_ISSUERS:
                raise ValueError("wrong issuer")
            if not _google_aud_ok(str(claims.get("aud", ""))):
                raise ValueError("audience not allowed")
            return claims
        except Exception as e:  # noqa: BLE001
            errors.append(f"google: {e}")

    raise TokenError("; ".join(errors) or "Token could not be verified")
