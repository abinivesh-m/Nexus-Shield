import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart' show AppColors;
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/lottie_result.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Map<String, List<HistoryItem>>? _grouped;
  List<HistoryItem>? _searchResults;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final grouped = await context.read<ApiService>().getHistoryGrouped();
      if (!mounted) return;
      setState(() => _grouped = grouped);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    try {
      final results = await context.read<ApiService>().searchHistory(query.trim());
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (_) {}
  }

  Future<void> _delete(String id) async {
    try {
      await context.read<ApiService>().deleteHistoryItem(id);
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      _showSnack(friendlyError(e));
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Clear all history?', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
        content: Text('This cannot be undone.', style: GoogleFonts.inter(color: AppColors.textSec)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Clear', style: GoogleFonts.inter(color: AppColors.brand, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) {
      if (!mounted) return;
      await context.read<ApiService>().clearHistory();
      if (!mounted) return;
      _load();
    }
  }

  Future<void> _export() async {
    final url = context.read<ApiService>().exportHistoryCsvUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      _showSnack('Could not open export link. Backend may not be reachable.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _riskColor(int score) {
    if (score >= 80) return AppColors.brand;
    if (score >= 60) return AppColors.orange;
    if (score >= 31) return AppColors.yellow;
    return AppColors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Analysis History'),
        actions: [
          IconButton(icon: const Icon(Icons.download_outlined), onPressed: _export, tooltip: 'Export CSV'),
          IconButton(icon: const Icon(Icons.delete_sweep_outlined), onPressed: _clearAll, tooltip: 'Clear all'),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _search,
              style: const TextStyle(color: AppColors.textPrim),
              decoration: InputDecoration(
                hintText: 'Search by scam type, summary, or content...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchResults = null);
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, color: AppColors.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSec)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }

    if (_searchResults != null) {
      if (_searchResults!.isEmpty) {
        return Center(child: Text('No matches found', style: GoogleFonts.inter(color: AppColors.textMuted)));
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _searchResults!.length,
        itemBuilder: (ctx, i) => _historyCard(_searchResults![i]),
      );
    }

    final grouped = _grouped ?? {};
    final nonEmptyBuckets = grouped.entries.where((e) => e.value.isNotEmpty).toList();
    if (nonEmptyBuckets.isEmpty) {
      return EmptyState(
        title: 'No scans yet',
        subtitle: 'Your scan history will appear here.\nStart by analyzing a suspicious message or URL.',
        onAction: () => Navigator.pop(context),
        actionLabel: 'Scan something now',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final bucket in nonEmptyBuckets) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(bucket.key, style: GoogleFonts.inter(
                  color: AppColors.textSec, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            for (final item in bucket.value) _historyCard(item),
          ],
        ],
      ),
    );
  }

  Widget _historyCard(HistoryItem item) {
    final color = _riskColor(item.riskScore);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _delete(item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48, height: 48,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value: item.riskScore / 100, strokeWidth: 5,
                  backgroundColor: color.withValues(alpha: 0.15), color: color, strokeCap: StrokeCap.round,
                ),
                Text('${item.riskScore}', style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(item.scamType, style: GoogleFonts.inter(
                      color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 14))),
                  if (item.matchedKnownScam)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text('DB MATCH', style: GoogleFonts.inter(color: AppColors.brand, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                ]),
                const SizedBox(height: 3),
                Text(item.summary, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 12.5)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(_iconFor(item.scanType), size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(_relativeTime(item.createdAt), style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(width: 10),
                  Text(item.category, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String scanType) {
    switch (scanType) {
      case 'screenshot': return Icons.image_outlined;
      case 'url': return Icons.link;
      case 'sms': return Icons.sms_outlined;
      case 'call': return Icons.call_outlined;
      default: return Icons.text_snippet_outlined;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
