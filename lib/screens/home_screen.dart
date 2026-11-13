import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/ui.dart';
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
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        subtle: true,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 6),
                  _buildHeroCard(context),
                  const SizedBox(height: 18),
                  _buildStatsRow(),
                  const SizedBox(height: 18),
                  _buildInternshipBanner(context),
                  const SizedBox(height: 26),
                  const SectionHeader(
                    title: 'Quick actions',
                    subtitle: 'One tap to check anything suspicious',
                  ),
                  const SizedBox(height: 12),
                  _buildActionGrid(context),
                  const SizedBox(height: 26),
                  const SectionHeader(
                    title: 'Scam types to watch',
                    subtitle: 'The five that hit India hardest right now',
                  ),
                  const SizedBox(height: 12),
                  _buildScamTypesList(),
                  const SizedBox(height: 26),
                  SectionHeader(
                    title: 'Recent alerts',
                    subtitle: 'Live signals from the NexusShield network',
                    trailing: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const IntelScreen())),
                      child: const Text('See all'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_threatItems.isEmpty)
                    GlassCard(
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined,
                              color: AppColors.green, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No active alerts in your region right now.',
                              style: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._threatItems.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildAlertCard(
                            e.value.title,
                            e.value.description,
                            e.value.severity.toUpperCase(),
                            _severityColor(e.value.severity),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const IntelScreen())),
                          ).animate().fadeIn(delay: (60 * e.key).ms),
                        )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 18,
      title: const BrandWordmark(size: 19),
      actions: [
        Pressable(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const IntelScreen())),
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none_rounded,
                    color: AppColors.textSec, size: 20),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: AppColors.brand, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Hero card ──────────────────────────────────────────────────────────
  Widget _buildHeroCard(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3B3C), Color(0xFF0A2438), Color(0xFF0F1729)],
        ),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.14),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -54,
            child: Opacity(
              opacity: 0.13,
              child: Transform.rotate(
                angle: -0.18,
                child: const BrandLogo(size: 210, glow: false),
              ),
            ),
          ),
          Positioned(
            right: -70,
            bottom: -90,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.cyan.withValues(alpha: 0.18),
                  AppColors.cyan.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatusPill(
                  label: 'AI SHIELD ACTIVE',
                  color: AppColors.green,
                  pulse: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'Stay protected\nfrom digital scams',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrim,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.14,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  width: 250,
                  child: Text(
                    'Upload a screenshot, paste a message or ask our AI — '
                    'know in seconds if it is a scam.',
                    style: GoogleFonts.inter(
                      color: AppColors.textSec,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Pressable(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ScreenshotAnalyzerScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image_search_rounded,
                            size: 18, color: Color(0xFF062A2E)),
                        const SizedBox(width: 8),
                        Text(
                          'Analyze a screenshot',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF062A2E),
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 420.ms).slideY(begin: -0.06, end: 0);
  }

  // ── Internship verifier banner ────────────────────────────────────────
  Widget _buildInternshipBanner(BuildContext context) {
    return GlassCard(
      accent: AppColors.orange,
      glow: true,
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const InternshipVerifierScreen())),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.orange.withValues(alpha: 0.30),
                AppColors.orange.withValues(alpha: 0.10),
              ]),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.verified_user_outlined,
                color: AppColors.orange, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Internship offer verifier',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrim,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Never pay a fee before checking the offer here.',
                  style: GoogleFonts.inter(
                    color: AppColors.textSec,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.06, end: 0);
  }

  // ── Stats row ──────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    const stats = [
      ('119', 'Contacts', AppColors.brand, Icons.people_alt_outlined),
      ('9', 'Countries', AppColors.blue, Icons.public_rounded),
      ('5', 'Scam types', AppColors.orange, Icons.warning_amber_rounded),
      ('24/7', 'AI guard', AppColors.green, Icons.bolt_rounded),
    ];
    return Row(
      children: stats.asMap().entries.map((e) {
        final i = e.key;
        final s = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < stats.length - 1 ? 8 : 0),
            child: StatTile(
              value: s.$1,
              label: s.$2,
              color: s.$3,
              icon: s.$4,
            ),
          ).animate().fadeIn(delay: (80 * i).ms).slideY(begin: 0.12, end: 0),
        );
      }).toList(),
    );
  }

  // ── Action grid ────────────────────────────────────────────────────────
  Widget _buildActionGrid(BuildContext context) {
    final actions = [
      (Icons.image_search_rounded, 'Screenshot', 'Analyzer', AppColors.brand,
          'Upload WhatsApp / SMS'),
      (Icons.text_snippet_outlined, 'Message', 'Analyzer', AppColors.orange,
          'Paste suspicious text'),
      (Icons.language_rounded, 'URL', 'Checker', AppColors.blue,
          'Spot fake websites'),
      (Icons.smart_toy_outlined, 'Scam', 'Copilot', AppColors.green,
          'Ask AI anything'),
      (Icons.record_voice_over_outlined, 'Scam call', 'Detector', AppColors.brand,
          'Analyze a transcript'),
      (Icons.currency_exchange_rounded, 'Currency', 'Scanner', AppColors.blue,
          'Spot counterfeit notes'),
      (Icons.map_outlined, 'Hotspot', 'Map', AppColors.orange,
          'Scams near you'),
      (Icons.hub_outlined, 'Fraud', 'Network', AppColors.violet,
          'Trace linked IDs'),
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
      mainAxisSpacing: 11,
      crossAxisSpacing: 11,
      childAspectRatio: 1.32,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: actions.asMap().entries.map((e) {
        final i = e.key;
        final a = e.value;
        return GlassCard(
          padding: const EdgeInsets.all(14),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => destinations[i])),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          a.$4.withValues(alpha: 0.30),
                          a.$4.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(11),
                      border:
                          Border.all(color: a.$4.withValues(alpha: 0.28)),
                    ),
                    child: Icon(a.$1, color: a.$4, size: 18),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded,
                      size: 13, color: Colors.white.withValues(alpha: 0.18)),
                ],
              ),
              const Spacer(),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: a.$2,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrim,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        height: 1.15,
                      ),
                    ),
                    TextSpan(
                      text: '\n${a.$3}',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrim.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                a.$5,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (50 * i).ms).scale(
              begin: const Offset(0.96, 0.96),
              curve: Curves.easeOutCubic,
            );
      }).toList(),
    );
  }

  // ── Scam types list ────────────────────────────────────────────────────
  Widget _buildScamTypesList() {
    final types = [
      (Icons.local_police_outlined, 'Digital arrest scam',
          'Fake police / CBI demanding money', AppColors.red),
      (Icons.account_balance_outlined, 'KYC / bank fraud',
          'Fake bank OTP and KYC phishing', AppColors.orange),
      (Icons.card_giftcard_rounded, 'Lottery & prize scam',
          '“You won” — pay a fee to claim', AppColors.yellow),
      (Icons.trending_up_rounded, 'Investment fraud',
          'Fake trading apps, pig butchering', AppColors.blue),
      (Icons.work_outline_rounded, 'Job offer scam',
          'Advance payment for fake jobs', AppColors.violet),
    ];
    return Column(
      children: types.asMap().entries.map((e) {
        final t = e.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            radius: 15,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: t.$4.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(t.$1, color: t.$4, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.$2,
                        style: GoogleFonts.inter(
                          color: AppColors.textPrim,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        t.$3,
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: t.$4, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (45 * e.key).ms);
      }).toList(),
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return AppColors.red;
      case 'high':
        return AppColors.orange;
      case 'medium':
        return AppColors.yellow;
      default:
        return AppColors.green;
    }
  }

  // ── Alert card ─────────────────────────────────────────────────────────
  Widget _buildAlertCard(String title, String desc, String badge, Color color,
      {VoidCallback? onTap}) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 15,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, color.withValues(alpha: 0.25)],
              ),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: AppColors.textPrim,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppColors.textSec,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(label: badge, color: color),
        ],
      ),
    );
  }
}
