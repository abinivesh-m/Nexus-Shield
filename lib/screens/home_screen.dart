import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'screenshot_analyzer_screen.dart';
import 'text_analyzer_screen.dart';
import 'url_checker_screen.dart';
import 'copilot_screen.dart';
import 'intel/intel_screen.dart';
import 'currency_scanner_screen.dart';
import 'hotspot_map_screen.dart';
import 'fraud_network_screen.dart';
import 'call_analyzer_screen.dart';
import 'internship_verifier_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ThreatFeedItem> _threatItems = [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadFeedAndNotifications();
  }

  Future<void> _loadFeedAndNotifications() async {
    final api = context.read<ApiService>();
    try {
      final items = await api.getThreatFeed();
      if (mounted) setState(() => _threatItems = items.take(3).toList());
    } catch (_) {}
    try {
      final notifs = await api.getNotifications(unreadOnly: true);
      if (mounted) setState(() => _unreadNotifications = notifs.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _buildHeroCard(context),
                const SizedBox(height: 20),
                _buildStatsRow(),
                const SizedBox(height: 20),
                _buildInternshipBanner(context),
                const SizedBox(height: 24),
                _buildSectionTitle('Quick Actions'),
                const SizedBox(height: 12),
                _buildActionGrid(context),
                const SizedBox(height: 24),
                _buildSectionTitle('Scam Types to Watch'),
                const SizedBox(height: 12),
                _buildScamTypesList(),
                const SizedBox(height: 24),
                _buildSectionTitle('Recent Alerts'),
                const SizedBox(height: 12),
                if (_threatItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Text('No active alerts in your region right now.',
                        style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12.5)),
                  )
                else
                  ..._threatItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildAlertCard(
                          item.title,
                          item.description,
                          item.severity.toUpperCase(),
                          _severityColor(item.severity),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IntelScreen())),
                        ),
                      )),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppColors.bg,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.red, AppColors.orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.security, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'NexusShield',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: AppColors.textPrim,
            ),
          ),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppColors.textSec),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IntelScreen())),
            ),
            if (_unreadNotifications > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Hero card ──────────────────────────────────────────────────────────
  Widget _buildHeroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1e293b), Color(0xFF162032)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.red.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'AI SHIELD ACTIVE',
                      style: GoogleFonts.inter(
                        color: AppColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Stay Protected\nfrom Digital Scams',
            style: GoogleFonts.inter(
              color: AppColors.textPrim,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a screenshot, paste a message,\nor ask our AI — instantly know if it\'s a scam.',
            style: GoogleFonts.inter(
              color: AppColors.textSec,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScreenshotAnalyzerScreen())),
              icon: const Icon(Icons.image_search, size: 18),
              label: const Text('Analyze Screenshot Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  // ── Internship verifier banner ────────────────────────────────────────
  Widget _buildInternshipBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InternshipVerifierScreen())),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7c2d12), Color(0xFF431407)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.verified_user_outlined, color: AppColors.orange, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🎓 Internship Offer Verifier', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('Before you pay any fee for an internship, check it here.', style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final stats = [
      ('119', 'Contacts', AppColors.red),
      ('9', 'Countries', AppColors.blue),
      ('5', 'Scam Types', AppColors.orange),
      ('24/7', 'AI Guard', AppColors.green),
    ];
    return Row(
      children: stats.asMap().entries.map((e) {
        final i = e.key;
        final s = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border(top: BorderSide(color: s.$3, width: 3)),
            ),
            child: Column(
              children: [
                Text(
                  s.$1,
                  style: GoogleFonts.inter(
                    color: s.$3,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.$2,
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ).animate().fadeIn(delay: (100 * i).ms),
        );
      }).toList(),
    );
  }

  // ── Section title ──────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: AppColors.textPrim,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ── Action grid ────────────────────────────────────────────────────────
  Widget _buildActionGrid(BuildContext context) {
    final actions = [
      (Icons.image_search, '📸 Screenshot\nAnalyzer', AppColors.red,
          'Upload WhatsApp/SMS screenshot'),
      (Icons.text_snippet_outlined, '📝 Message\nAnalyzer', AppColors.orange,
          'Paste suspicious text'),
      (Icons.language, '🌐 URL\nChecker', AppColors.blue,
          'Check fake websites'),
      (Icons.smart_toy_outlined, '🤖 Scam\nCopilot', AppColors.green,
          'Ask AI anything'),
      (Icons.record_voice_over_outlined, '📞 Scam Call\nDetector', AppColors.red,
          'Analyze a call transcript'),
      (Icons.currency_exchange, '💵 Currency\nScanner', AppColors.blue,
          'Check for counterfeit notes'),
      (Icons.map_outlined, '🗺️ Hotspot\nMap', AppColors.orange,
          'See scam hotspots near you'),
      (Icons.hub_outlined, '🕸️ Fraud\nNetwork', AppColors.red,
          'Trace linked scam identifiers'),
    ];
    final destinations = [
      const ScreenshotAnalyzerScreen(),
      const TextAnalyzerScreen(),
      const UrlCheckerScreen(),
      const CopilotScreen(),
      const CallAnalyzerScreen(),
      const CurrencyScannerScreen(),
      const HotspotMapScreen(),
      const FraudNetworkScreen(),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: actions.asMap().entries.map((e) {
        final i = e.key;
        final a = e.value;
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destinations[i])),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: a.$3.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(a.$1, color: a.$3, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  a.$2,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrim,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (80 * i).ms).scale(begin: const Offset(0.95, 0.95)),
        );
      }).toList(),
    );
  }

  // ── Scam types list ────────────────────────────────────────────────────
  Widget _buildScamTypesList() {
    final types = [
      ('🚔', 'Digital Arrest Scam', 'Fake police/CBI demanding money', AppColors.red),
      ('🏦', 'KYC / Bank Fraud', 'Fake bank OTP and KYC phishing', AppColors.orange),
      ('🎰', 'Lottery & Prize Scam', 'You won — pay fees to claim', AppColors.yellow),
      ('💸', 'Investment Fraud', 'Fake trading platforms, Pig Butchering', AppColors.blue),
      ('💼', 'Job Offer Scam', 'Advance payment for fake jobs', AppColors.textSec),
    ];
    return Column(
      children: types.asMap().entries.map((e) {
        final t = e.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Text(t.$1, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.$2,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrim,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      t.$3,
                      style: GoogleFonts.inter(
                        color: AppColors.textSec,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: t.$4,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (60 * e.key).ms);
      }).toList(),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical': return AppColors.red;
      case 'high': return AppColors.orange;
      case 'medium': return AppColors.yellow;
      default: return AppColors.green;
    }
  }

  // ── Alert card ─────────────────────────────────────────────────────────
  Widget _buildAlertCard(String title, String desc, String badge, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrim,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    color: AppColors.textSec,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              badge,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
