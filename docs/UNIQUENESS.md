# The one feature: Verified Offer Receipts

## The 15-second answer

> Every other scam checker gives you an **opinion**. We give you a **receipt** —
> a signed record that a placement cell can check, and that we can **revoke**
> if the offer later turns out to be fake.

That is the whole pitch. Everything below is proof.

## Why an opinion is not enough

A student pastes an offer, gets "Likely genuine 12%", and screenshots it. That
screenshot proves nothing:

- it can be edited in any photo app
- it cannot be checked by a placement officer
- it goes stale the moment the scam campaign is understood
- it is worthless to anyone other than the person who generated it

So every existing checker produces a dead end. The verdict is consumed and
forgotten.

## What a receipt is

When the verifier finishes, it issues a receipt:

```
NS-82252323A2
issued 2026-11-19 · verdict: Likely genuine · score: 10
employer domain: hackerrank.com
signature: b73a882d... (HMAC-SHA256 over the fields above)
```

Three properties make it different from a screenshot:

| Property | Why it matters |
|---|---|
| **Tamper-evident** | The signature covers the verdict. Editing "genuine" to "scam" — or the reverse — breaks it. |
| **Third-party checkable** | `GET /receipt/{id}` is public and needs no account. A placement cell can verify without installing anything. |
| **Revocable** | If the offer is later confirmed as a scam, every receipt for it is invalidated. Holders see "do not proceed". |

## The part nobody else ships: retroactive revocation

Scam campaigns are usually understood *after* the fact. A cloned offer looks
clean on Monday and is identified as fraud on Friday.

Every other tool is a snapshot: it can only ever be as right as it was at the
moment you asked.

A receipt has a **lifecycle**. Revoking by offer hash invalidates every receipt
ever issued for that exact offer — including ones already sitting in students'
WhatsApp chats. The verdict is no longer a one-time opinion; it is a live
record that can be corrected.

This is the actual invention. Not "AI detects scams" — that is a commodity.
**A verdict that can be revoked.**

## Why a scammer cannot game it

- They cannot forge a receipt: they do not have the signing key.
- They cannot reuse a genuine receipt for a different offer: the offer hash is
  inside the signature.
- They cannot edit a stored receipt: the signature is stored separately and
  verified on every read (there is a test for exactly this).

## What we do *not* claim

Investors trust a founder more when the boundaries are explicit.

- We do **not** prevent cyberattacks. We prevent one specific loss: a student
  paying a fake internship fee.
- We do **not** guarantee an offer is genuine. A receipt is evidence, not a
  warranty.
- We do **not** compete with Truecaller on caller ID, or with AICTE on company
  registration. We sit where neither can: the individual offer a student
  receives on WhatsApp at 11pm.

## The moat behind the feature

Two things compound and cannot be copied by a competitor who starts today:

1. **The receipt registry** — every verification, permanently addressable.
2. **Labelled outcomes** — every "this verdict was wrong" correction, paired
   with the verdict that was issued. That is ground truth on real Indian
   internship offers, which nobody else collects.

The app is the wedge. The registry and the dataset are the business.

## The 30-second demo

1. Paste a real HackerRank Campus Crew offer → **10/100, Likely genuine,
   verified `hackerrank.com`** → receipt `NS-…`
2. Open `/receipt/NS-…` on a second device → **valid, authentic**
3. Revoke it as an administrator → same URL → **revoked: confirmed clone
   campaign**
4. Paste the clone → **95/100, Likely scam**, look-alike domain flagged

Step 3 is the moment people remember, because nobody expects a verdict to be
able to change its mind.

## One-line answers for the questions you will get

**"Isn't this just another AI scam checker?"**
> No. AI checkers produce an opinion. We produce a signed, checkable,
> revocable record. The AI is a component; the receipt is the product.

**"What stops Truecaller from doing this?"**
> Nothing stops them building a checker — they already have one. But a receipt
> is only useful if a third party accepts it. That requires a placement cell
> relationship, not an app install. We start where the decision is made.

**"What is defensible?"**
> The registry of issued receipts and the labelled corrections. Both grow with
> every student and neither can be bought.

**"Why now?"**
> Internship fraud moved to WhatsApp and look-alike domains. Detection alone
> cannot keep up, because the campaign changes after the check. A record that
> can be revoked is the only structure that survives that.

**"What is the proof it works?"**
> 32 backend tests, including tamper detection and revocation. A live
> end-to-end run: real offer → 10/100 genuine → receipt → revoke → revoked.
