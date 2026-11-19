import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';

/// National scam picture, with every number traceable to a published source.
///
/// This screen deliberately contains no invented statistics. An earlier
/// version showed a fabricated category split, a fabricated monthly bar chart
/// and fabricated state counts. In a security product that is worse than
/// showing nothing: it looks like intelligence and is not.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Source: Ministry of Home Affairs / I4C, figures released July 2025.
  static const String _source =
      'Source: Ministry of Home Affairs / I4C (2024 data, released July 2025)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scam Intelligence')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildTopStats(context),
            const SizedBox(height: 8),
            Text(
              _source,
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Scams that reach students'),
            const SizedBox(height: 4),
            Text(
              'These four account for most of what students report to us.',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 12),
            ..._buildScamCards(),
            const SizedBox(height: 24),
            _buildReportCard(context),
            const SizedBox(height: 16),
            Text(
              'NexusShield does not estimate national totals. Numbers on this '
              'screen come from published government data, and the rest is '
              'described in words rather than invented percentages.',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withValues(alpha: 0.12),
            AppColors.orange.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹22,845 Crore',
                  style: GoogleFonts.inter(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                Text(
                  'Lost to cyber fraud in India in 2024 - up 206% on 2023',
                  style: GoogleFonts.inter(
                    color: AppColors.textSec,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Text('📊', style: TextStyle(fontSize: 32)),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.1, end: 0);
  }

  Widget _buildTopStats(BuildContext context) {
    final stats = <(String, String, Color)>[
      ('36.4 lakh', 'Complaints\nin 2024', AppColors.red),
      ('+206%', 'Rise in losses\nvs 2023', AppColors.orange),
      ('1930', 'National\nHelpline', AppColors.green),
      ('cybercrime\n.gov.in', 'Report\nonline', AppColors.blue),
    ];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: stats.asMap().entries.map((e) {
        final s = e.value;
        final isHelpline = s.$1 == '1930';
        final isPortal = s.$1.startsWith('cybercrime');
        return InkWell(
          onTap: isHelpline
              ? () => _open(context, 'tel:1930')
              : isPortal
                  ? () => _open(context, 'https://cybercrime.gov.in')
                  : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: s.$3, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s.$1,
                  style: GoogleFonts.inter(
                    color: s.$3,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                Text(
                  s.$2,
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (80 * e.key).ms);
      }).toList(),
    );
  }

  List<Widget> _buildScamCards() {
    final scams = <(String, String, Color)>[
      (
        'Fake internship offers',
        'A "registration" or "security deposit" before joining, sent over '
            'WhatsApp or a look-alike domain. Real employers pay you.',
        AppColors.brand,
      ),
      (
        'Digital arrest',
        'A caller claiming to be police or CBI, on video, demanding money to '
            'avoid arrest. No agency arrests anyone over a call.',
        AppColors.red,
      ),
      (
        'UPI and OTP fraud',
        'A "refund" or "receive money" request that is actually a payment. '
            'Nobody needs your UPI PIN to send you money.',
        AppColors.orange,
      ),
      (
        'Investment and task scams',
        'Small payouts to build trust, then a large deposit that never comes '
            'back. If you must pay to earn, it is not a job.',
        AppColors.blue,
      ),
    ];

    return scams.asMap().entries.map((e) {
      final s = e.value;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: s.$3, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.$1,
              style: GoogleFonts.inter(
                color: AppColors.textPrim,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              s.$2,
              style: GoogleFonts.inter(
                color: AppColors.textSec,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: (60 * e.key).ms);
    }).toList();
  }

  Widget _buildReportCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚨', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Got scammed? Report immediately.',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrim,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'The sooner you report, the better the chance of stopping '
                      'the payment.',
                      style: GoogleFonts.inter(
                        color: AppColors.textSec,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open(context, 'tel:1930'),
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: const Text('Call 1930'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _open(context, 'https://cybercrime.gov.in'),
                  icon: const Icon(Icons.public, size: 16),
                  label: const Text('Report online'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: GoogleFonts.inter(
          color: AppColors.textPrim,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      );

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }
}
