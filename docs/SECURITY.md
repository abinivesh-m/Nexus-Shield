# Security

NexusShield handles internship offers and scam reports — data a student trusts
us with. Security is not a feature we add later; it is the product.

## What is already enforced

- **Transport**: HTTPS only, HSTS (`max-age=31536000; includeSubDomains`), `X-Frame-Options: DENY`,
  `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`.
- **Authentication**: bcrypt password hashing, JWT access (30 min) + refresh (30 days) tokens,
  server-side sessions, refresh-token rotation.
- **Brute force**: account lockout after 5 failed logins (15 min) and a sliding-window rate
  limiter (60 req/min per IP). Login attempts (success, failure, unknown email) are audited
  with the client IP.
- **Secrets**: `JWT_SECRET` and `RECEIPT_SECRET` fail closed in production. There is no
  weak default that can be used to forge tokens.
- **Data at rest**: offer text is never stored raw — only a SHA-256 hash and a redacted
  preview (emails, phones, UPI IDs, links removed). Receipts store the verdict and the
  employer domain only.
- **Data in transit to AI**: offer text goes to Google Gemini over HTTPS for analysis.
- **Receipts**: HMAC-SHA256 signed, verified on every read, retroactively revocable.
- **Privacy**: first-run consent gate (versioned), in-app privacy notice, account deletion
  removes every associated record.
- **Input validation**: every text/url/transcript/offer/image field has a max length;
  passwords require 10+ characters.
- **CORS**: restricted to known frontends, no wildcard.
- **Dependencies**: no SQL injection (ORM), no XSS in the receipt page (`html.escape`).

## What you must configure (Vercel environment variables)

Set these in the Vercel dashboard for the backend project. Without them the
corresponding feature returns `503` rather than leaking data.

| Variable | Purpose | Free option |
|---|---|---|
| `JWT_SECRET` | Signs access/refresh tokens | `openssl rand -hex 32` |
| `RECEIPT_SECRET` | Signs verification receipts (falls back to `JWT_SECRET`) | same as above |
| `DATABASE_URL` | Neon Postgres connection string | Neon free tier |
| `GEMINI_API_KEY` | Google Gemini API key | Google AI Studio free tier |
| `ADMIN_SEED_PASSWORD` | Initial admin password (only used on first seed) | choose a strong one |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM` | Email delivery for OTPs and reset links | Brevo (300/day free) or Gmail app password |
| `FAST2SMS_API_KEY` | SMS delivery for OTPs (India) | Fast2SMS free trial |

## What you must rotate (do this now)

These were exposed in earlier chat logs and must be treated as compromised:

- Gemini key `***REMOVED-SECRET***` / `***REMOVED-SECRET***`
- Firebase key `***REMOVED-SECRET***`
- Neon password `***REMOVED-SECRET***`
- HuggingFace token `***REMOVED-SECRET***`

Rotate each in its provider console, then update the Vercel env vars.

## What is deliberately NOT in this pilot

- Certificate pinning (standard for mobile banking apps; not needed for 20 students)
- Biometric app lock enforcement (the setting exists; wiring is roadmap)
- End-to-end encryption of stored offers (we store a hash + redacted preview, not the raw text, which is the practical equivalent for this threat model)
- WAF / DDoS protection beyond Vercel's defaults (fine for a pilot)

## Reporting a vulnerability

Email abinivesh.1203@gmail.com. We will acknowledge within 72 hours.
PY