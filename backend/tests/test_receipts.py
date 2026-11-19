"""Tests for verified offer receipts and pilot feedback.

These cover the two claims the pilot has to be able to defend:

  1. A receipt cannot be altered without the signature failing.
  2. One confirmed scam invalidates every receipt issued for that offer.

Run:  python -m unittest discover -s backend/tests -v
"""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import HTTPException  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402

from app import models, schemas, receipts  # noqa: E402
from app import internship_verifier  # noqa: E402
from app.database import Base  # noqa: E402
from app.routers import admin_router, internship_router  # noqa: E402


class ReceiptTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        engine = create_engine(
            f"sqlite:///{os.path.join(self.tmp, 'test.db')}",
            connect_args={"check_same_thread": False},
        )
        Base.metadata.create_all(engine)
        self.Session = sessionmaker(bind=engine)
        self.db = self.Session()
        self.user = models.User(email="student@college.edu", name="Student")
        self.admin = models.User(email="admin@nexusshield.app", name="Admin", is_admin=True)
        self.db.add_all([self.user, self.admin])
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def _issue(self, verdict="Likely genuine", score=12, domain="hackerrank.com",
               verified=True, text="HackerRank Campus Crew 2026"):
        return internship_router._issue_receipt(
            self.db,
            self.user,
            {
                "verdict": verdict,
                "risk_score": score,
                "official_website": domain,
                "company_verified": verified,
                "red_flags": [],
            },
            text,
        )


class ReceiptIntegrity(ReceiptTestCase):
    def test_receipt_roundtrip_is_valid(self):
        issued = self._issue()
        view = internship_router.get_receipt(issued["id"], self.db)
        self.assertTrue(view["valid"])
        self.assertFalse(view["revoked"])
        self.assertEqual(view["verdict"], "Likely genuine")
        self.assertEqual(view["employer_domain"], "hackerrank.com")
        self.assertTrue(view["company_verified"])

    def test_receipt_id_is_short_and_copyable(self):
        issued = self._issue()
        self.assertTrue(issued["id"].startswith("NS-"))
        self.assertEqual(len(issued["id"]), 13)

    def test_tampered_receipt_fails_signature(self):
        issued = self._issue()
        row = self.db.query(models.OfferReceipt).filter_by(id=issued["id"]).first()
        row.verdict = "Likely scam"  # someone edits the database
        self.db.commit()

        view = internship_router.get_receipt(issued["id"], self.db)
        self.assertFalse(view["valid"])

    def test_signature_covers_the_verdict(self):
        a = receipts.issue("Likely genuine", 12, "hackerrank.com", True, "abc")
        b = receipts.issue("Likely scam", 12, "hackerrank.com", True, "abc")
        self.assertNotEqual(a[3], b[3])

    def test_unknown_receipt_is_404(self):
        with self.assertRaises(HTTPException) as ctx:
            internship_router.get_receipt("NS-NOTAREAL1", self.db)
        self.assertEqual(ctx.exception.status_code, 404)

    def test_receipt_does_not_expose_the_offer(self):
        issued = self._issue(text="My private message with my phone number 98765 43210")
        view = internship_router.get_receipt(issued["id"], self.db)
        self.assertNotIn("98765", str(view))
        self.assertNotIn("private message", str(view))


class RetroactiveRevocation(ReceiptTestCase):
    def test_revocation_by_offer_hash_hits_every_receipt(self):
        first = self._issue()
        second = self._issue()  # same offer text -> same hash

        digest = internship_verifier.offer_hash("HackerRank Campus Crew 2026")
        result = admin_router.revoke_receipts(
            schemas.ReceiptRevokeRequest(
                offer_hash=digest,
                reason="Confirmed clone campaign",
            ),
            self.admin,
            self.db,
        )
        self.assertEqual(result["revoked"], 2)

        for rid in (first["id"], second["id"]):
            view = internship_router.get_receipt(rid, self.db)
            self.assertTrue(view["revoked"])
            self.assertIn("clone", view["revoked_reason"].lower())
            # A revoked receipt is still authentic - it was really issued.
            self.assertTrue(view["valid"])

    def test_revocation_of_one_receipt_leaves_others_alone(self):
        first = self._issue()
        second = self._issue()

        admin_router.revoke_receipts(
            schemas.ReceiptRevokeRequest(receipt_id=first["id"], reason="Typo"),
            self.admin,
            self.db,
        )

        self.assertTrue(internship_router.get_receipt(first["id"], self.db)["revoked"])
        self.assertFalse(internship_router.get_receipt(second["id"], self.db)["revoked"])

    def test_revoke_requires_a_target(self):
        with self.assertRaises(HTTPException) as ctx:
            admin_router.revoke_receipts(
                schemas.ReceiptRevokeRequest(reason="nothing"), self.admin, self.db
            )
        self.assertEqual(ctx.exception.status_code, 400)

    def test_revoke_unknown_offer_hash_is_404(self):
        with self.assertRaises(HTTPException) as ctx:
            admin_router.revoke_receipts(
                schemas.ReceiptRevokeRequest(offer_hash="0" * 64), self.admin, self.db
            )
        self.assertEqual(ctx.exception.status_code, 404)


class FeedbackCapture(ReceiptTestCase):
    def _submit(self, **kwargs):
        payload = dict(
            offer_text="Secret offer from Acme",
            predicted_verdict="Likely scam",
            predicted_score=90,
            actual_verdict="genuine",
            reason="real_offer",
        )
        payload.update(kwargs)
        return internship_router.internship_feedback(
            schemas.InternshipFeedbackRequest(**payload), self.user, self.db
        )

    def test_feedback_is_recorded(self):
        out = self._submit()
        self.assertTrue(out["recorded"])
        row = self.db.query(models.InternshipFeedback).first()
        self.assertEqual(row.actual_verdict, "genuine")
        self.assertEqual(row.predicted_verdict, "Likely scam")

    def test_feedback_stores_only_a_hash(self):
        self._submit()
        row = self.db.query(models.InternshipFeedback).first()
        self.assertEqual(len(row.offer_hash), 64)
        self.assertNotIn("Secret", str(row.__dict__))
        self.assertNotIn("Acme", str(row.__dict__))

    def test_feedback_rejects_unknown_verdict(self):
        with self.assertRaises(HTTPException) as ctx:
            self._submit(actual_verdict="maybe")
        self.assertEqual(ctx.exception.status_code, 400)

    def test_feedback_allows_correction_without_text(self):
        out = self._submit(offer_text="")
        self.assertTrue(out["recorded"])
        row = self.db.query(models.InternshipFeedback).first()
        self.assertEqual(row.offer_hash, "")


class PilotAccuracyMath(ReceiptTestCase):
    def test_precision_and_recall(self):
        cases = [
            ("Likely scam", "scam"),      # true positive
            ("Likely scam", "scam"),      # true positive
            ("Likely scam", "genuine"),   # false positive
            ("Likely genuine", "genuine"),  # true negative
        ]
        for predicted, actual in cases:
            self.db.add(models.InternshipFeedback(
                user_id=self.user.id,
                predicted_verdict=predicted,
                predicted_score=80,
                actual_verdict=actual,
            ))
        self.db.commit()

        out = admin_router.internship_feedback_summary(self.admin, self.db)
        self.assertEqual(out["confusion"]["true_positive"], 2)
        self.assertEqual(out["confusion"]["false_positive"], 1)
        self.assertAlmostEqual(out["precision"], 0.6667)
        self.assertEqual(out["recall"], 1.0)
        # 1 false positive out of 1 scam-flagged + 1 genuine = 0.5
        self.assertAlmostEqual(out["false_positive_rate"], 0.5)

    def test_no_data_returns_none_not_a_fake_number(self):
        out = admin_router.internship_feedback_summary(self.admin, self.db)
        self.assertEqual(out["total_feedback"], 0)
        self.assertIsNone(out["precision"])
        self.assertIsNone(out["recall"])

    def test_disagreements_are_listed(self):
        self.db.add(models.InternshipFeedback(
            user_id=self.user.id, predicted_verdict="Likely genuine",
            predicted_score=12, actual_verdict="scam", reason="real_offer",
        ))
        self.db.commit()
        out = admin_router.internship_feedback_summary(self.admin, self.db)
        self.assertEqual(len(out["disagreements"]), 1)
        self.assertEqual(out["disagreements"][0]["actual_verdict"], "scam")


if __name__ == "__main__":
    unittest.main(verbosity=2)
