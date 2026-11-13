import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../widgets/risk_meter.dart';
import '../widgets/lottie_result.dart';

class CallAnalyzerScreen extends StatefulWidget {
  const CallAnalyzerScreen({super.key});
  @override
  State<CallAnalyzerScreen> createState() => _CallAnalyzerScreenState();
}

class _CallAnalyzerScreenState extends State<CallAnalyzerScreen> {
  final _transcriptCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  bool _analyzing = false;
  AnalysisResult? _result;

  final _sample =
      "Caller: This is Inspector Sharma from Cyber Crime Cell, Delhi. Your Aadhaar "
      "number has been used to send illegal parcels. There is an arrest warrant "
      "against your name. Do not disconnect this call or inform anyone. Switch on "
      "video and stay on the line. To verify you are not involved, transfer "
      "₹50,000 to this RBI verification account within 30 minutes or a team will "
      "arrive to arrest you.";

  Future<void> _analyze() async {
    final transcript = _transcriptCtrl.text.trim();
    if (transcript.isEmpty) return;
    setState(() { _analyzing = true; _result = null; });
    try {
      final api = context.read<ApiService>();
      final lang = api.currentUser?.language ?? 'en';
      final result = await api.analyzeCall(transcript, callerNumber: _numberCtrl.text.trim(), language: lang);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      _showError(friendlyError(e));
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scam Call Detector'), centerTitle: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubtitle(),
            const SizedBox(height: 16),
            _buildNumberField(),
            const SizedBox(height: 12),
            _buildTranscriptField(),
            const SizedBox(height: 12),
            if (_transcriptCtrl.text.isNotEmpty) _buildAnalyzeButton(),
            if (_analyzing) ...[const SizedBox(height: 24), _buildLoadingState()],
            if (_result != null) ...[const SizedBox(height: 24), _buildResultCard()],
            const SizedBox(height: 20),
            _buildPrototypeNotice(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paste the transcript of a suspicious call — especially calls claiming to be '
          'police/CBI/customs/RBI demanding urgent payment ("digital arrest" scams). '
          'Our AI flags authority-impersonation and pressure tactics.',
          style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => _transcriptCtrl.text = _sample),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppColors.border),
            ),
            child: Text('Try a sample digital-arrest transcript',
                style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField() {
    return TextField(
      controller: _numberCtrl,
      style: GoogleFonts.inter(color: AppColors.textPrim, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'Caller number (optional)',
        hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  Widget _buildTranscriptField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _transcriptCtrl.text.isNotEmpty ? AppColors.brand.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: _transcriptCtrl,
            maxLines: 8,
            style: GoogleFonts.inter(color: AppColors.textPrim, fontSize: 13.5, height: 1.6),
            decoration: InputDecoration(
              hintText: 'Paste or type the call transcript here...',
              hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.6),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_transcriptCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Text('${_transcriptCtrl.text.length} characters',
                      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () { _transcriptCtrl.clear(); setState(() { _result = null; }); },
                    child: Text('Clear', style: GoogleFonts.inter(color: AppColors.brand, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _analyzing ? null : _analyze,
        icon: const Icon(Icons.record_voice_over_outlined, size: 18),
        label: const Text('Analyze Call'),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    ).animate().fadeIn().slideY(begin: 0.2, end: 0);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            LottieResult(state: LottieState.scanning, message: '🤖 AI is analyzing the call...'),
            const SizedBox(height: 8),
            Text(
              'Checking for authority impersonation, urgency, and payment pressure',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildResultCard() {
    final r = _result!;
    final color = r.riskScore >= 75 ? AppColors.red : r.riskScore >= 40 ? AppColors.orange : AppColors.green;
    final label = r.riskScore >= 75 ? 'HIGH RISK' : r.riskScore >= 40 ? 'MEDIUM RISK' : 'LIKELY SAFE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.scamType, style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                          child: Text(label, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.4)),
                        ),
                      ],
                    ),
                  ),
                  RiskMeter(score: r.riskScore, color: color),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Text(r.summary, style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13, height: 1.5)),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),

        if (r.redFlags.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('🚩 Red Flags', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          ...r.redFlags.asMap().entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.brand.withValues(alpha: 0.2))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️ ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.value.flag, style: GoogleFonts.inter(color: AppColors.textPrim, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                      if (e.value.detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(e.value.detail, style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 12, height: 1.4)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (80 * e.key).ms)),
        ],

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.green.withValues(alpha: 0.25))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ What You Should Do', style: GoogleFonts.inter(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Text(r.advice, style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13, height: 1.5)),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '⚠️ SCAM CALL ALERT: ${r.scamType}\nRisk: ${r.riskScore}%\n${r.advice}'));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert copied to clipboard')));
            },
            icon: const Icon(Icons.share_outlined, size: 16, color: AppColors.textSec),
            label: Text('Share Warning', style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrototypeNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Prototype notice: this analyzes a transcript you paste in after a call — it does not '
        'intercept or listen to live calls. Real-time in-call audio detection needs a native '
        'Android foreground service and telephony permissions, which is roadmap, not live here.',
        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11.5, height: 1.4),
      ),
    );
  }
}
