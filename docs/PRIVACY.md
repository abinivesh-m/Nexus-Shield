# Privacy Notice — Internship Pilot

Version: 2026-11-19

This notice describes exactly what the NexusShield internship verifier does
with the text a student pastes. It matches the notice shown in the app
(`lib/screens/pilot/privacy_notice_screen.dart`). If the data flow changes, both
must change together.

## What is sent

When a student taps **Verify Offer**, the pasted offer text is sent over HTTPS
to the NexusShield backend and then to Google's Gemini API so the offer can be
read and assessed.

## What is stored

- the verdict and risk score
- the red flags and the advice text
- a SHA-256 hash of the offer (one-way, cannot be reversed)
- a **redacted** preview of the offer, with email addresses, phone numbers,
  UPI IDs and links replaced by `[email]`, `[phone]`, `[upi]` and `[link]`
- a verification receipt: verdict, risk score, employer domain, offer hash

The raw offer text is **not** stored.

## What is never stored

Passwords, OTPs, bank account numbers, card numbers, Aadhaar and PAN. The
verifier never asks for them.

## Receipts are public by ID

`GET /receipt/{id}` is unauthenticated so a placement cell can verify a receipt
without an account. A receipt contains the verdict, the score, the employer
domain and the offer hash. It contains no message text and no student identity.

## Corrections

When a student reports that a verdict was wrong, the correction is stored with
the predicted verdict, the actual outcome and a hash of the offer. Corrections
are used to measure accuracy and are never shown to other students.

## Retention and deletion

Deleting an account removes the user's scan history, receipts, corrections and
sessions. This is implemented in `DELETE /profile/me` (cascade delete).

## Security

- All traffic is HTTPS.
- Receipts are signed with HMAC-SHA256 and verified on every read.
- Authentication uses short-lived access tokens plus refresh tokens.

## Contact

abinivesh.1203@gmail.com
