import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../main.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
            _buildTopStats(),
            const SizedBox(height: 24),
            _sectionTitle('Scam Type Distribution'),
            const SizedBox(height: 12),
            _buildPieChart(),
            const SizedBox(height: 24),
            _sectionTitle('Monthly Scam Reports (India)'),
            const SizedBox(height: 12),
            _buildBarChart(),
            const SizedBox(height: 24),
            _sectionTitle('Most Targeted States'),
            const SizedBox(height: 12),
            _buildStateList(),
            const SizedBox(height: 24),
            _buildReportCard(),
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
          colors: [AppColors.red.withValues(alpha: 0.12), AppColors.orange.withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹11,269 Crore',
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                Text(
                  'Lost to cyber fraud in India (2023)',
                  style: GoogleFonts.inter(
                    color: AppColors.textSec,
                    fontSize: 12,
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

  Widget _buildTopStats() {
    final stats = [
      ('7,40,957', 'Cases Reported\n2023', AppColors.red),
      ('₹1.77L Cr', 'At Risk\n(2027 est.)', AppColors.orange),
      ('45%', 'Investment\nFraud Share', AppColors.blue),
      ('1930', 'National\nHelpline', AppColors.green),
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
        return Container(
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
        ).animate().fadeIn(delay: (80 * e.key).ms);
      }).toList(),
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

  Widget _buildPieChart() {
    final data = [
      ('Investment Fraud', 45.0, AppColors.blue),
      ('Digital Arrest', 18.0, AppColors.red),
      ('KYC / Bank', 15.0, AppColors.orange),
      ('Lottery Scam', 12.0, AppColors.yellow),
      ('Other', 10.0, AppColors.textMuted),
    ];
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: data.map((d) => PieChartSectionData(
                  value: d.$2,
                  color: d.$3,
                  radius: 60,
                  showTitle: false,
                )).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: d.$3, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${d.$1} ${d.$2.toInt()}%',
                    style: GoogleFonts.inter(
                      color: AppColors.textSec,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildBarChart() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final values = [42.0, 55.0, 48.0, 70.0, 65.0, 88.0];

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  months[v.toInt()],
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: values.asMap().entries.map((e) => BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                gradient: const LinearGradient(
                  colors: [AppColors.red, AppColors.orange],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          )).toList(),
        ),
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _buildStateList() {
    final states = [
      ('Maharashtra', '1,40,812', 0.9),
      ('Uttar Pradesh', '98,545', 0.75),
      ('Rajasthan', '87,231', 0.65),
      ('Telangana', '72,114', 0.55),
      ('Tamil Nadu', '65,890', 0.48),
    ];
    return Column(
      children: states.asMap().entries.map((e) {
        final s = e.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Text(
                '${e.key + 1}',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.$1,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrim,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: s.$3,
                      backgroundColor: AppColors.border,
                      color: AppColors.red,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                s.$2,
                style: GoogleFonts.inter(
                  color: AppColors.textSec,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (60 * e.key).ms);
      }).toList(),
    );
  }

  Widget _buildReportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
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
                  'National Helpline: 1930 | Cybercrime: cybercrime.gov.in',
                  style: GoogleFonts.inter(
                    color: AppColors.textSec,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
