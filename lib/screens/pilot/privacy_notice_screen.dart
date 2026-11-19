import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../main.dart';

/// The privacy notice shown before a student uses the verifier.
///
/// Every sentence here is checked against what the backend actually does.
/// If the data flow changes, this text must change with it.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  static const String version = '2026-11-19';

  static const List<(String, String)> _sections = [
    (
      'What you send',
      'When you tap "Verify Offer", the offer text you pasted is sent to the '
          'NexusShield server and then to Google\'s Gemini API so the offer can '
          'be read and assessed. The text travels over HTTPS.',
    ),
    (
      'What we store',
      'We store the verdict, the risk score, the red flags, the advice, and a '
          'one-way hash of the offer. We also store a redacted preview with email '
          'addresses, phone numbers, UPI IDs and links removed. We do not store '
          'the raw message.',
    ),
    (
      'What we never store',
      'We never store your password, OTPs, bank account numbers, card numbers, '
          'Aadhaar or PAN. The verifier never asks for them, and you should never '
          'paste them into any app.',
    ),
    (
      'Verification receipts',
      'Each verdict gets a receipt ID. Anyone with that ID, such as your '
          'placement cell, can check it. A receipt contains the verdict and the '
          'employer domain only. It never contains your message or your identity.',
    ),
    (
      'Corrections',
      'If you tell us a verdict was wrong, we store your correction together '
          'with a hash of the offer. This is how accuracy is measured. It is '
          'never shown to other students.',
    ),
    (
      'Your control',
      'You can delete your account and all associated records at any time from '
          'Profile. Deleting your account removes your history, receipts and '
          'corrections.',
    ),
    (
      'This is a pilot',
      'The verifier can be wrong in both directions. A "Likely genuine" result '
          'is not a guarantee. Always confirm an offer on the employer\'s own '
          'website before paying anything or sharing documents.',
    ),
    (
      'Contact',
      'Questions or a data request: abinivesh.1203@gmail.com',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Notice')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'NexusShield Internship Pilot',
            style: GoogleFonts.inter(
              color: AppColors.textPrim,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Notice version $version',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          for (final section in _sections) ...[
            Text(
              section.$1,
              style: GoogleFonts.inter(
                color: AppColors.brand,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              section.$2,
              style: GoogleFonts.inter(
                color: AppColors.textSec,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
