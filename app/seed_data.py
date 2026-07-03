"""
Seed data for first boot: a starter local scam database, threat feed
items, and cybersecurity news/advisories. All illustrative/synthetic —
swap in real CERT-In / telecom-reported feeds via `ingest_external_feed`
hooks once those credentials are available.
"""
import datetime as dt
from sqlalchemy.orm import Session as DBSession

from . import models

SCAM_DB_SEED = [
    # URLs / domains
    {"entry_type": "domain", "value": "sbi-kyc-verify.xyz", "category": "Phishing", "severity": "critical", "notes": "Fake SBI KYC update page."},
    {"entry_type": "domain", "value": "indiapost-tracking.info", "category": "Courier Scam", "severity": "high", "notes": "Fake India Post tracking/customs-fee page."},
    {"entry_type": "domain", "value": "income-tax-refund-gov.in.net", "category": "Phishing", "severity": "critical", "notes": "Spoofed income tax refund portal."},
    {"entry_type": "domain", "value": "irctc-refund-claim.com", "category": "Phishing", "severity": "high", "notes": "Fake IRCTC refund claim page."},
    {"entry_type": "url", "value": "bit.ly/win-iphone-now", "category": "Lottery Scam", "severity": "high", "notes": "Fake prize/lottery shortlink."},
    # Phone numbers (synthetic examples for demo)
    {"entry_type": "phone", "value": "8800123456", "category": "Digital Arrest Scam", "severity": "critical", "notes": "Reported impersonating CBI officer on video call."},
    {"entry_type": "phone", "value": "7000987654", "category": "OTP Scam", "severity": "high", "notes": "Reported requesting OTP claiming to be bank support."},
    {"entry_type": "phone", "value": "9123456780", "category": "Job Scam", "severity": "medium", "notes": "Reported offering fake work-from-home jobs requiring upfront fee."},
    # UPI IDs
    {"entry_type": "upi", "value": "fastrefund@ybl", "category": "UPI Fraud", "severity": "critical", "notes": "Reported in multiple refund-scam complaints."},
    {"entry_type": "upi", "value": "winprize@paytm", "category": "Lottery Scam", "severity": "high", "notes": "Reported collecting 'processing fee' for fake prizes."},
]

THREAT_FEED_SEED = [
    {"title": "Fake SBI KYC SMS targeting Tamil Nadu", "description": "Bulk SMS campaign impersonating SBI asking users to 'update KYC' via a phishing link. Do not click links in unsolicited bank SMS.", "region": "Tamil Nadu", "category": "Phishing", "severity": "high"},
    {"title": "Digital arrest scam calls rising in Bengaluru", "description": "Fraudsters posing as CBI/Customs officials are trapping victims on video calls demanding money to avoid 'arrest'. Real agencies never demand payment over video call.", "region": "Karnataka", "category": "Digital Arrest Scam", "severity": "critical"},
    {"title": "Fake courier customs-fee texts nationwide", "description": "SMS claiming a parcel is held at customs and asking for a small fee via a link. The link leads to a card-skimming page.", "region": "India", "category": "Courier Scam", "severity": "medium"},
    {"title": "Investment 'pig butchering' scams via WhatsApp", "description": "Scammers build trust over weeks before directing victims to fake trading apps that lock withdrawals after large deposits.", "region": "India", "category": "Investment Scam", "severity": "high"},
]

NEWS_SEED = [
    {"title": "CERT-In advisory on fake government portal phishing", "summary": "CERT-In flagged a wave of spoofed .gov.in look-alike domains used to harvest personal and banking details.", "source": "CERT-In", "category": "cert-in"},
    {"title": "RBI reiterates: banks never ask for OTP over phone", "summary": "The Reserve Bank of India reminded customers that bank staff will never call asking for OTPs, PINs, or CVVs.", "source": "RBI", "category": "advisory"},
    {"title": "Cybercrime helpline 1930 sees record call volume", "summary": "The national cybercrime helpline reported rising calls related to digital arrest and UPI fraud cases this quarter.", "source": "Ministry of Home Affairs", "category": "advisory"},
]


def seed_if_empty(db: DBSession):
    if db.query(models.ScamDatabaseEntry).count() == 0:
        for item in SCAM_DB_SEED:
            db.add(models.ScamDatabaseEntry(**item, source="admin"))

    if db.query(models.ThreatFeedItem).count() == 0:
        for item in THREAT_FEED_SEED:
            db.add(models.ThreatFeedItem(**item))

    if db.query(models.NewsItem).count() == 0:
        for item in NEWS_SEED:
            db.add(models.NewsItem(**item, url=""))

    # Demo admin account so the admin panel is reachable out of the box.
    if db.query(models.User).filter(models.User.email == "admin@nexusshield.app").first() is None:
        from .auth import hash_password
        admin = models.User(
            email="admin@nexusshield.app",
            password_hash=hash_password("ChangeMe123!"),
            name="NexusShield Admin",
            is_admin=True,
            is_email_verified=True,
        )
        db.add(admin)

    db.commit()
