import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import 'privacy_notice_screen.dart';

/// Tracks whether the current privacy notice has been accepted.
///
/// Versioned on purpose: if the notice changes materially, bump
/// [PrivacyNoticeScreen.version] and every student is asked again.
class PilotConsent {
  static const String _key = 'pilot_consent_version';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == PrivacyNoticeScreen.version;
  }

  static Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, PrivacyNoticeScreen.version);
  }

  static Future<void> revoke() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Blocking consent gate shown before the verifier can be used.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _checked = false;

  Future<void> _continue() async {
    await PilotConsent.accept();
    if (!mounted) return;
    widget.onAccepted();
  }

  void _openNotice() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyNoticeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Before you start')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: AppColors.brand, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Internship pilot',
                        style: GoogleFonts.inter(
                          color: AppColors.textPrim,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _point(
                  'What is sent',
                  'The offer text goes to our server and to Google Gemini for '
                      'analysis. It is sent over HTTPS.',
                ),
                _point(
                  'What is stored',
                  'The verdict, the red flags, and a hash of the offer. Emails, '
                      'phone numbers, UPI IDs and links are removed from the '
                      'stored preview.',
                ),
                _point(
                  'What is never stored',
                  'Passwords, OTPs, bank or card numbers, Aadhaar and PAN. '
                      'Never paste those anywhere.',
                ),
                _point(
                  'Your control',
                  'You can delete your account and every record from Profile at '
                      'any time.',
                ),
                _point(
                  'This is a pilot',
                  'It can be wrong. A "Likely genuine" result is not a '
                      'guarantee - confirm on the employer\'s own website before '
                      'paying anything.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => setState(() => _checked = !_checked),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: Checkbox(
                      value: _checked,
                      onChanged: (v) => setState(() => _checked = v ?? false),
                      activeColor: AppColors.brand,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'I have read the privacy notice and I agree to my offer '
                      'text being analysed.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSec,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _openNotice,
            icon: const Icon(Icons.article_outlined, size: 16),
            label: const Text('Read the full privacy notice'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _checked ? _continue : null,
              child: const Text('I agree - continue'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(
              'Not now',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _point(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.textPrim,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: GoogleFonts.inter(
              color: AppColors.textSec,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
