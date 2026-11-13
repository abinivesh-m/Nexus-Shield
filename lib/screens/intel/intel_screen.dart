import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show AppColors;
import '../../models/models.dart';
import '../../services/api_service.dart';

class IntelScreen extends StatefulWidget {
  const IntelScreen({super.key});
  @override
  State<IntelScreen> createState() => _IntelScreenState();
}

class _IntelScreenState extends State<IntelScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Security Intelligence'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.brand,
          labelColor: AppColors.textPrim,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [Tab(text: 'Threat Feed'), Tab(text: 'News & Advisories')],
        ),
      ),
      body: TabBarView(controller: _tab, children: const [_ThreatFeedTab(), _NewsTab()]),
    );
  }
}

class _ThreatFeedTab extends StatefulWidget {
  const _ThreatFeedTab();
  @override
  State<_ThreatFeedTab> createState() => _ThreatFeedTabState();
}

class _ThreatFeedTabState extends State<_ThreatFeedTab> {
  List<ThreatFeedItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<ApiService>().getThreatFeed();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _items = []);
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical': return AppColors.red;
      case 'high': return AppColors.orange;
      case 'medium': return AppColors.yellow;
      default: return AppColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    if (_items!.isEmpty) {
      return Center(child: Text('No active threat alerts', style: GoogleFonts.inter(color: AppColors.textMuted)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items!.length,
        itemBuilder: (ctx, i) {
          final item = _items![i];
          final color = _severityColor(item.severity);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(item.severity.toUpperCase(), style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(item.region, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11))),
              ]),
              const SizedBox(height: 8),
              Text(item.title, style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              Text(item.description, style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
              const SizedBox(height: 8),
              Text(item.source, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
            ]),
          );
        },
      ),
    );
  }
}

class _NewsTab extends StatefulWidget {
  const _NewsTab();
  @override
  State<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<_NewsTab> {
  List<NewsItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<ApiService>().getNews();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _items = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items == null) return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    if (_items!.isEmpty) {
      return Center(child: Text('No news yet', style: GoogleFonts.inter(color: AppColors.textMuted)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items!.length,
        itemBuilder: (ctx, i) {
          final item = _items![i];
          final isCertIn = item.category == 'cert-in';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(isCertIn ? Icons.verified_user_outlined : Icons.newspaper, size: 14, color: AppColors.blue),
                const SizedBox(width: 6),
                Text(item.source, style: GoogleFonts.inter(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Text(item.title, style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 14.5)),
              const SizedBox(height: 6),
              Text(item.summary, style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
            ]),
          );
        },
      ),
    );
  }
}
