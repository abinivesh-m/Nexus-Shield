import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show AppColors;
import '../../services/api_service.dart';

/// Phase 4 (dashboard) + Phase 10 (personal analytics), built on the user's
/// own scan history -- distinct from the national-statistics DashboardScreen
/// ("Stats" tab), which shows India-wide context rather than personal data.
class PersonalDashboardScreen extends StatefulWidget {
  const PersonalDashboardScreen({super.key});
  @override
  State<PersonalDashboardScreen> createState() => _PersonalDashboardScreenState();
}

class _PersonalDashboardScreenState extends State<PersonalDashboardScreen> {
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _analytics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final summary = await api.getDashboardSummary();
      final analytics = await api.getPersonalAnalytics();
      if (!mounted) return;
      setState(() { _summary = summary; _analytics = analytics; });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('My Protection Dashboard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.brand,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _buildTodayRow(),
                  const SizedBox(height: 20),
                  Text('Weekly activity', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  _buildWeeklyChart(),
                  const SizedBox(height: 24),
                  Text('Safe vs Risky', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  _buildRiskBreakdown(),
                  const SizedBox(height: 24),
                  Text('Most common scam type', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  _buildMostCommon(),
                ],
              ),
            ),
    );
  }

  Widget _buildTodayRow() {
    final today = _summary?['today_scans'] ?? 0;
    final highRisk = _summary?['high_risk_detections'] ?? 0;
    final safe = _summary?['safe_scans'] ?? 0;
    final total = _summary?['total_scans'] ?? 0;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.7,
      children: [
        _stat('Today', '$today', Icons.today_outlined, AppColors.blue),
        _stat('High Risk Found', '$highRisk', Icons.warning_amber_rounded, AppColors.red),
        _stat('Safe Scans', '$safe', Icons.check_circle_outline, AppColors.green),
        _stat('All-Time Total', '$total', Icons.shield_outlined, AppColors.orange),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _buildWeeklyChart() {
    final trend = List<Map<String, dynamic>>.from(_summary?['weekly_trend'] ?? []);
    if (trend.isEmpty) {
      return Container(
        height: 120, alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Text('No scans yet this week', style: GoogleFonts.inter(color: AppColors.textMuted)),
      );
    }
    final maxY = trend.map((d) => (d['count'] as int)).fold<int>(1, (a, b) => a > b ? a : b).toDouble();
    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: BarChart(
        BarChartData(
          maxY: maxY + 1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
              final idx = v.toInt();
              if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
              final dateStr = trend[idx]['date'] as String;
              final day = DateTime.parse(dateStr);
              const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              return Text(labels[day.weekday - 1], style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10));
            })),
          ),
          barGroups: trend.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(
              toY: (e.value['count'] as int).toDouble(),
              color: AppColors.brand, width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
          ])).toList(),
        ),
      ),
    );
  }

  Widget _buildRiskBreakdown() {
    final safe = _analytics?['safe_count'] ?? 0;
    final suspicious = _analytics?['suspicious_count'] ?? 0;
    final risky = _analytics?['risky_count'] ?? 0;
    final total = safe + suspicious + risky;
    if (total == 0) {
      return Text('No scans yet', style: GoogleFonts.inter(color: AppColors.textMuted));
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 120,
            child: PieChart(PieChartData(
              sectionsSpace: 2, centerSpaceRadius: 28,
              sections: [
                if (safe > 0) PieChartSectionData(value: safe.toDouble(), color: AppColors.green, showTitle: false, radius: 40),
                if (suspicious > 0) PieChartSectionData(value: suspicious.toDouble(), color: AppColors.yellow, showTitle: false, radius: 40),
                if (risky > 0) PieChartSectionData(value: risky.toDouble(), color: AppColors.brand, showTitle: false, radius: 40),
              ],
            )),
          ),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _legendRow(AppColors.green, 'Safe', safe),
          _legendRow(AppColors.yellow, 'Suspicious', suspicious),
          _legendRow(AppColors.brand, 'Risky', risky),
        ]),
      ]),
    );
  }

  Widget _legendRow(Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label: $count', style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 12)),
      ]),
    );
  }

  Widget _buildMostCommon() {
    final mostCommon = _analytics?['most_common_scam_type'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        const Icon(Icons.bug_report_outlined, color: AppColors.orange, size: 28),
        const SizedBox(width: 12),
        Text(mostCommon ?? 'Not enough data yet', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 15)),
      ]),
    );
  }
}
