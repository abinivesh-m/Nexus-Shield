# NexusShield — Security Overview

Prepared for the IT / Security review team at Sri Krishna College of Engineering and Technology (SKCET).

## 1. Authentication & Session Management

- **JWT access tokens** (short-lived) + **refresh tokens** (30-day, individually revocable) issued on login / signup / OAuth.
- Passwords are hashed with **bcrypt** (passlib). Plain-text passwords are never stored or logged.
- **Google Sign-In** is verified server-side against Google's `tokeninfo` endpoint; the `aud` (client ID), `email`, and `email_verified` claims are validated before a session is issued. Mismatched or forged tokens are rejected with HTTP 401.
- Session management: each device gets a distinct refresh token stored in the `sessions` table; users can list and revoke individual sessions from the app (Profile → Sessions). Logout revokes the refresh token.
- Password reset and email verification use single-use, time-expiring tokens (2h / 24h).

## 2. Data Isolation

- Every authenticated request resolves the user from the JWT (`get_current_user`). All data queries (scan history, reports, notifications, family links, org membership) are filtered by `user_id` / `organization_id`.
- Verified by test: User A's scan history is not visible to User B; User B receives HTTP 403 when attempting admin endpoints.
- Family links are explicit opt-in: a guardian invites a member by email; alerts are sent only when a linked member's scan exceeds the configured risk threshold.
- Organization data is scoped to members of that organization only.

## 3. Transport & API Security

- All production traffic is over **HTTPS** (Vercel provides TLS + HSTS header `max-age=31536000; includeSubDomains`).
- **CORS** is restricted to the known frontend origin (`https://nexus-shield-iota.vercel.app`) plus local development origins. No wildcard (`*`) in production.
- Security headers on every response: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`.
- **Rate limiting**: 60 requests / 60 seconds per IP (in-memory). Analysis endpoints additionally depend on Gemini quota; abusive clients receive HTTP 429.

## 4. Input Validation & Injection Prevention

- All request bodies are validated with **Pydantic** schemas (typed fields, length constraints, email validation).
- Database access uses **SQLAlchemy ORM** with parameterized queries — no raw string interpolation. No SQL injection surface.
- User-generated content (scam reports, chat messages) is stored as text and rendered by Flutter's safe text widgets; no HTML/JS evaluation occurs.
- File uploads (screenshots) are accepted as base64 and decoded server-side; size limits enforced by the platform (HTTP 413).

## 5. Secrets & Key Management

- All secrets (`GEMINI_API_KEY`, `JWT_SECRET`, DB credentials, OAuth client IDs) are stored in **environment variables**, never in source code.
- The Gemini API key is **server-side only**; the Flutter client never holds or sees it.
- `.env` is git-ignored; production secrets are set in the Vercel dashboard.
- Keys can be rotated at any time without code changes.

## 6. Database Security

- Production uses **PostgreSQL** (Vercel/Neon) over SSL. Local development uses SQLite for zero-config setup.
- Schema uses foreign keys with cascade rules; no cross-user joins leak data.
- User passwords are never returned in any API response. Admin endpoints are gated by `is_admin` flag checked on every request.
- Sensitive operations (account deletion, session revocation) require a valid access token.

## 7. Privacy & Data Handling

- **No user data is shared between accounts or sold to third parties.**
- Scan history, reports, and chat messages are stored per-user and accessible only to that user (and, for family protection, to a linked guardian who explicitly opted in).
- The app does not perform background clipboard or call monitoring; checks occur only when the app is in the foreground and only after explicit user consent.
- Data is transmitted only over HTTPS; no analytics trackers are embedded in the client.

## 8. Abuse & Fraud Prevention in the App Itself

- AI analysis results are cached (24h) to reduce cost and prevent replay abuse.
- When the AI service is unavailable, the app returns a rule-based verdict instead of failing open — the user is never told "service unavailable" without actionable guidance.
- Admin panel is reachable only by accounts with `is_admin = true`; the default demo admin credentials must be changed before any real deployment.

## 9. Known Limitations (Roadmap)

- Refresh tokens are not rotated on use (planned).
- Email delivery (verification / password reset) is not wired to a real provider in the open-source build; tokens are returned for demo purposes only.
- Push notifications are polled, not pushed, in the open-source build.
- Real-time (live) call interception requires a native Android service and is not yet implemented.

## 10. Contact

For security questions or to report a vulnerability, contact the project maintainer. Responsible disclosure is appreciated; please allow reasonable time for a fix before public disclosure.
