import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../widgets/risk_meter.dart';
import '../widgets/lottie_result.dart';

class TextAnalyzerScreen extends StatefulWidget {
  const TextAnalyzerScreen({super.key});
  @override
  State<TextAnalyzerScreen> createState() => _TextAnalyzerScreenState();
}

class _TextAnalyzerScreenState extends State<TextAnalyzerScreen> {
  final _ctrl = TextEditingController();
  bool _analyzing = false;
  AnalysisResult? _result;

  final List<String> _samples = [
    "Dear Sir, Your Aadhaar has been used for illegal activity. You are under digital arrest. Call 9876543210 immediately or face 7 years imprisonment.",
    "Congratulations! Your KYC update is pending. Your account will be blocked in 24 hours. Click: http://sbi-kyc-update.xyz to verify now.",
    "You have won ₹25,00,000 in KBC Lottery. To claim, pay ₹5000 processing fee to account 1234567890 IFSC: HDFC0001234.",
    "Hi, I'm Priya from HR. We have a part-time job opening — earn ₹5000/day by liking YouTube videos. Initial deposit ₹2000 for activation.",
  ];

  Future<void> _analyze() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _analyzing = true; _result = null; });
    try {
      final api = context.read<ApiService>();
      final lang = api.currentUser?.language ?? 'en';
      final result = await api.analyzeText(text, language: lang);
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
      appBar: AppBar(title: const Text('Message Analyzer'), centerTitle: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSubtitle(),
            const SizedBox(height: 16),
            _buildSampleStrip(),
            const SizedBox(height: 16),
            _buildInputArea(),
            const SizedBox(height: 12),
            if (_ctrl.text.isNotEmpty) _buildAnalyzeButton(),
            if (_analyzing) ...[const SizedBox(height: 24), _buildLoadingState()],
            if (_result != null) ...[const SizedBox(height: 24), _buildResultCard()],
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle() => Text(
    'Paste a suspicious WhatsApp message, SMS, or call transcript. '
    'Our AI will detect fraud patterns instantly.',
    style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13, height: 1.5),
  );

  Widget _buildSampleStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Try a sample:', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _samples.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () {
                _ctrl.text = _samples[i];
                setState(() {});
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Sample ${i + 1}',
                  style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ctrl.text.isNotEmpty ? AppColors.red.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: _ctrl,
            maxLines: 8,
            style: GoogleFonts.inter(color: AppColors.textPrim, fontSize: 13.5, height: 1.6),
            decoration: InputDecoration(
              hintText: 'Paste suspicious message here...\n\nExample: "Your Aadhaar has been linked to illegal activity. You are under digital arrest..."',
              hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, height: 1.6),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_ctrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Text(
                    '${_ctrl.text.length} characters',
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () { _ctrl.clear(); setState(() { _result = null; }); },
                    child: Text('Clear', style: GoogleFonts.inter(color: AppColors.red, fontSize: 11, fontWeight: FontWeight.w600)),
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
        icon: const Icon(Icons.psychology, size: 18),
        label: const Text('Analyze with AI'),
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
            LottieResult(
              state: LottieState.scanning,
              message: '🤖 AI is analyzing the message...',
            ),
            const SizedBox(height: 8),
            Text(
              'Scanning for fraud patterns, threat language, and red flags',
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
        // Risk header
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
            decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.red.withValues(alpha: 0.2))),
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
              Clipboard.setData(ClipboardData(text: '⚠️ SCAM ALERT: ${r.scamType}\nRisk: ${r.riskScore}%\n${r.advice}'));
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
}
