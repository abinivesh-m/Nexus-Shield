import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/api_service.dart';
import 'pilot/consent_screen.dart';
import 'pilot/privacy_notice_screen.dart';

class InternshipVerifierScreen extends StatefulWidget {
  const InternshipVerifierScreen({super.key});
  @override
  State<InternshipVerifierScreen> createState() => _InternshipVerifierScreenState();
}

class _InternshipVerifierScreenState extends State<InternshipVerifierScreen> {
  final _ctrl = TextEditingController();
  bool _analyzing = false;
  Map<String, dynamic>? _result;

  bool? _consented;
  bool _feedbackBusy = false;
  String? _feedbackGiven;

  final _sample = "Congratulations! You have been selected for a paid internship at TechCorp. "
      "Stipend: Rs. 45,000/month. No experience required. To confirm your seat, pay a "
      "registration fee of Rs. 2,500 to secure@techcorp@gmail.com. No interview needed. "
      "Contact recruiter at techcorp.jobs@gmail.com.";

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final accepted = await PilotConsent.isAccepted();
    if (!mounted) return;
    setState(() => _consented = accepted);
  }

  Future<void> _analyze() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _analyzing = true;
      _result = null;
      _feedbackGiven = null;
    });
    try {
      final api = context.read<ApiService>();
      final lang = api.currentUser?.language ?? 'en';
      final res = await api.analyzeInternship(text, language: lang);
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyError(e)),
        backgroundColor: AppColors.red,
      ));
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Color _color(int score) =>
      score >= 70 ? AppColors.red : score >= 40 ? AppColors.orange : AppColors.green;

  Future<void> _copyReceipt(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Receipt $id copied')),
    );
  }

  Future<void> _sendFeedback(String actual) async {
    final r = _result;
    if (r == null || _feedbackBusy) return;
    setState(() => _feedbackBusy = true);
    try {
      final api = context.read<ApiService>();
      await api.submitInternshipFeedback(
        offerText: _ctrl.text,
        predictedVerdict: (r['verdict'] ?? '').toString(),
        predictedScore: (r['risk_score'] as num?)?.toInt() ?? 0,
        actualVerdict: actual,
        historyId: r['history_id']?.toString(),
        reason: actual == 'genuine'
            ? 'reported_real_offer'
            : actual == 'scam'
                ? 'reported_scam'
                : 'not_sure',
      );
      if (!mounted) return;
      setState(() => _feedbackGiven = actual);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks - your correction was recorded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyError(e)),
        backgroundColor: AppColors.red,
      ));
    } finally {
      if (mounted) setState(() => _feedbackBusy = false);
    }
  }

  Future<void> _reportWrong() async {
    final actual = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                'What is the offer really?',
                style: GoogleFonts.inter(
                  color: AppColors.textPrim,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: AppColors.green),
              title: const Text('It is a real offer'),
              subtitle: const Text('The verifier was too harsh'),
              onTap: () => Navigator.pop(ctx, 'genuine'),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: AppColors.red),
              title: const Text('It is actually a scam'),
              subtitle: const Text('The verifier was too lenient'),
              onTap: () => Navigator.pop(ctx, 'scam'),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppColors.textMuted),
              title: const Text('I am not sure yet'),
              subtitle: const Text('Record it as unresolved'),
              onTap: () => Navigator.pop(ctx, 'unsure'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (actual != null) await _sendFeedback(actual);
  }

  @override
  Widget build(BuildContext context) {
    if (_consented == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_consented == false) {
      return ConsentScreen(
        onAccepted: () => setState(() => _consented = true),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Internship Offer Verifier'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Privacy notice',
            icon: const Icon(Icons.privacy_tip_outlined, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyNoticeScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste an internship or job offer. We verify the company exists online, '
              'match the recruiter email domain, check domain age, and flag scam patterns.',
              style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _ctrl.text = _sample),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.border)),
                child: Text('Try a sample scam offer', style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: TextField(
                controller: _ctrl,
                maxLines: 10,
                style: GoogleFonts.inter(color: AppColors.textPrim, fontSize: 13.5, height: 1.6),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(16), hintText: 'Paste offer text here...'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
            if (_ctrl.text.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _analyzing ? null : _analyze,
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Verify Offer'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            if (_analyzing) ...[
              const SizedBox(height: 24),
              Center(child: Column(children: [
                const CircularProgressIndicator(color: AppColors.brand),
                const SizedBox(height: 8),
                Text('Searching company & verifying domains...', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
              ])),
            ],
            if (_result != null) ...[const SizedBox(height: 24), _buildResult()],
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final r = _result!;
    final score = (r['risk_score'] as num?)?.toInt() ?? 0;
    final color = _color(score);
    final verdict = (r['verdict'] ?? '').toString();
    final redFlags = (r['red_flags'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.4))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(r['scam_type']?.toString() ?? 'Offer Analysis', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w800, fontSize: 15))),
                  Text('$score%', style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w800, fontSize: 22)),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                child: Text(verdict, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
              const SizedBox(height: 10),
              if ((r['company_name'] ?? '').toString().isNotEmpty)
                Text('Company: ${r['company_name']}', style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
              if ((r['official_website'] ?? '').toString().isNotEmpty)
                Text('Official site: ${r['official_website']}', style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
              Text('Domain match: ${r['domain_match'] == true ? "Yes" : "No"}', style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
              const SizedBox(height: 10),
              Text(r['summary']?.toString() ?? '', style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13, height: 1.5)),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
        if (redFlags.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('🚩 Red Flags', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          ...redFlags.asMap().entries.map((e) {
            final f = e.value as Map;
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.brand.withValues(alpha: 0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f['flag']?.toString() ?? '', style: GoogleFonts.inter(color: AppColors.textPrim, fontSize: 13, fontWeight: FontWeight.w600)),
                if ((f['detail'] ?? '').toString().isNotEmpty)
                  Text(f['detail'].toString(), style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 12, height: 1.4)),
              ]),
            ).animate().fadeIn(delay: (80 * e.key).ms);
          }),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.green.withValues(alpha: 0.25))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('✅ What You Should Do', style: GoogleFonts.inter(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Text(r['advice']?.toString() ?? '', style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13, height: 1.5)),
          ]),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 14),
        _buildReceipt(),
        const SizedBox(height: 14),
        _buildFeedback(),
      ],
    );
  }

  Widget _buildReceipt() {
    final receipt = _result?['receipt'];
    if (receipt is! Map) return const SizedBox.shrink();
    final id = (receipt['id'] ?? '').toString();
    if (id.isEmpty) return const SizedBox.shrink();
    final issued = (receipt['issued_at'] ?? '').toString();
    final issuedDate = issued.length >= 10 ? issued.substring(0, 10) : issued;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Verification receipt',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrim,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy receipt ID',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textSec),
                onPressed: () => _copyReceipt(id),
              ),
            ],
          ),
          SelectableText(
            id,
            style: GoogleFonts.jetBrainsMono(
              color: AppColors.brand,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Issued $issuedDate. Anyone with this ID can verify it - including your '
            'placement cell. It can be revoked later if the offer turns out to be fake.',
            style: GoogleFonts.inter(
              color: AppColors.textSec,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback() {
    if (_feedbackGiven != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Correction recorded. Thank you - this is how the verifier improves.',
                style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Was this verdict right?',
            style: GoogleFonts.inter(
              color: AppColors.textPrim,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Your answer is the ground truth we measure accuracy against.',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _feedbackBusy
                      ? null
                      : () {
                          final score =
                              (_result?['risk_score'] as num?)?.toInt() ?? 0;
                          _sendFeedback(score >= 40 ? 'scam' : 'genuine');
                        },
                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 15),
                  label: const Text('Yes, correct'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _feedbackBusy ? null : _reportWrong,
                  icon: const Icon(Icons.thumb_down_alt_outlined, size: 15),
                  label: const Text('No, it is wrong'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
