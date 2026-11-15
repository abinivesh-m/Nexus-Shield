"""Regression tests for the internship verifier.

Two failure modes matter equally:
  * a real offer flagged as a scam (student misses an opportunity)
  * a fake offer cleared as genuine (student loses money)

Run:  python -m unittest discover -s backend/tests -v
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import internship_verifier as iv  # noqa: E402


def analyse(text, ai=None):
    """Run the verifier with the model either disabled or stubbed."""
    original = iv.ai_engine.analyze_internship_offer

    def _offline(**kwargs):
        raise RuntimeError("offline")

    iv.ai_engine.analyze_internship_offer = ai or _offline
    iv._CACHE.clear()
    try:
        return iv.run(text, "en")
    finally:
        iv.ai_engine.analyze_internship_offer = original


REAL_HACKERRANK = """HackerRank Campus Crew 2026 - Internship Programme

Congratulations! You have been selected for the HackerRank Campus Crew, a
student ambassador programme for campus developers.

Role: Campus Crew Intern
Stipend: Rs. 15,000/month
Duration: 6 months, remote
Apply: https://www.hackerrank.com/campus-crew
Contact: campus@hackerrank.com
"""

REAL_GOOGLE = """Google STEP Internship 2026

You have been shortlisted for the Student Training in Engineering Program.
Stipend: Rs. 80,000/month
Location: Bengaluru
Apply through https://careers.google.com/students
Recruiter: university@google.com
"""

REAL_INFOSYS = """Infosys Summer Internship 2026

Role: Systems Engineer Intern
Stipend: Rs. 20,000 per month
Location: Mysuru
Selection: online assessment followed by a technical interview.
Contact: internships@infosys.com
"""

SCAM_CLONE = """HackerRank Campus Crew - SELECTED

You are selected for HackerRank Campus Crew internship with Google.
Stipend Rs. 45,000/month, no experience required, no interview needed.
Pay a one-time registration fee of Rs 499 to confirm your seat.
Apply now: https://hackerrank-jobs.xyz/apply
Contact: hr.hackerrank@gmail.com
"""

SCAM_UPI = """Google Internship Offer Letter

Congratulations, you are selected. Pay the security deposit of Rs 2,500 to
hr.google.offers@ybl to receive your offer letter today.
Stipend: Rs 90,000/month, no experience required.
"""

SCAM_TCS = """TCS Direct Joining - Work From Home

No interview. No experience needed. Salary Rs 55,000/month.
Registration charge Rs 999. Apply at https://tcs-careers.xyz/join
"""

NAMEDROP = """Google Summer Internship 2026
You have been shortlisted. Stipend Rs 60,000/month.
Reply to this message to confirm your seat.
"""


class RealOffersAreNotScams(unittest.TestCase):
    def test_hackerrank_campus_crew(self):
        r = analyse(REAL_HACKERRANK)
        self.assertTrue(r["company_verified"])
        self.assertLessEqual(r["risk_score"], 25)
        self.assertEqual(r["verdict"], "Likely genuine")
        self.assertEqual(r["red_flags"], [])

    def test_google_step(self):
        r = analyse(REAL_GOOGLE)
        self.assertTrue(r["company_verified"])
        self.assertLessEqual(r["risk_score"], 25)
        self.assertNotEqual(r["verdict"], "Likely scam")

    def test_infosys_internship(self):
        r = analyse(REAL_INFOSYS)
        self.assertTrue(r["company_verified"])
        self.assertLessEqual(r["risk_score"], 25)

    def test_model_cannot_accuse_a_confirmed_employer(self):
        def _harsh(**kwargs):
            return {"risk_score": 88, "verdict": "Likely scam",
                    "scam_type": "Job Scam", "category": "Job Scam",
                    "summary": "x", "advice": "y",
                    "red_flags": [{"flag": "Company not found online",
                                   "detail": "x"}]}

        r = analyse(REAL_HACKERRANK, ai=_harsh)
        self.assertLessEqual(r["risk_score"], 25)
        self.assertEqual(r["verdict"], "Likely genuine")
        self.assertEqual(r["red_flags"], [])


class ScamsAreCaught(unittest.TestCase):
    def test_clone_of_real_programme(self):
        r = analyse(SCAM_CLONE)
        self.assertGreaterEqual(r["risk_score"], 70)
        self.assertEqual(r["verdict"], "Likely scam")
        flags = {f["flag"] for f in r["red_flags"]}
        self.assertIn("Registration fee requested", flags)
        self.assertIn("Look-alike domain", flags)

    def test_upi_deposit(self):
        r = analyse(SCAM_UPI)
        self.assertGreaterEqual(r["risk_score"], 70)
        flags = {f["flag"] for f in r["red_flags"]}
        self.assertTrue({"Payment to a personal UPI ID",
                         "Registration fee requested"} & flags)

    def test_typosquat_employer_domain(self):
        r = analyse(SCAM_TCS)
        self.assertGreaterEqual(r["risk_score"], 70)
        self.assertIn("Look-alike domain",
                      {f["flag"] for f in r["red_flags"]})


class AmbiguousIsHonest(unittest.TestCase):
    def test_name_drop_is_not_an_accusation(self):
        r = analyse(NAMEDROP)
        self.assertLessEqual(r["risk_score"], 55)
        self.assertNotEqual(r["verdict"], "Likely scam")
        self.assertIn("Unverified brand claim",
                      {f["flag"] for f in r["red_flags"]})

    def test_unverifiable_is_not_a_clean_bill(self):
        r = analyse("Internship available. Contact us for details.")
        self.assertGreaterEqual(r["risk_score"], 40)
        self.assertNotEqual(r["verdict"], "Likely genuine")


class DomainHelpers(unittest.TestCase):
    def test_registrable(self):
        self.assertEqual(iv._registrable("mail.hackerrank.com"), "hackerrank.com")
        self.assertEqual(iv._registrable("www.google.co.in"), "google.co.in")

    def test_lookalike_detection(self):
        self.assertEqual(
            iv._lookalike_domain("hackerrank.com", {"hackerrank-jobs.xyz"}),
            "hackerrank-jobs.xyz")
        self.assertEqual(
            iv._lookalike_domain("google.com", {"google.co.in"}), "")

    def test_evidence_extraction(self):
        found = iv.extract_evidence_domains(
            "apply at https://www.hackerrank.com/x or mail campus@hackerrank.com")
        self.assertIn("hackerrank.com", found)


if __name__ == "__main__":
    unittest.main(verbosity=2)
