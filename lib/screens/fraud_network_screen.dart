import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/api_service.dart';

class FraudNetworkScreen extends StatefulWidget {
  const FraudNetworkScreen({super.key});
  @override
  State<FraudNetworkScreen> createState() => _FraudNetworkScreenState();
}

class _FraudNetworkScreenState extends State<FraudNetworkScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  FraudNetworkGraph? _graph;

  Future<void> _search() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() { _loading = true; _error = null; _graph = null; });
    try {
      final api = context.read<ApiService>();
      final graph = await api.getFraudNetwork(value);
      setState(() => _graph = graph);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'phone_number':
        return Icons.phone_iphone;
      case 'upi_id':
        return Icons.account_balance_wallet_outlined;
      case 'bank_account':
        return Icons.account_balance_outlined;
      case 'device_id':
        return Icons.smartphone_outlined;
      case 'website':
        return Icons.language;
      default:
        return Icons.hub_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'phone_number':
        return AppColors.red;
      case 'upi_id':
        return AppColors.orange;
      case 'bank_account':
        return AppColors.blue;
      case 'device_id':
        return AppColors.yellow;
      case 'website':
        return AppColors.green;
      default:
        return AppColors.textSec;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fraud Network Graph'), centerTitle: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search a phone number, UPI ID, website, or account to see every '
              'other identifier it has been linked to across scam reports.',
              style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 24),
            if (_loading) _buildLoading(),
            if (_error != null) _buildError(),
            if (_graph != null) _buildGraphResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            style: GoogleFonts.inter(color: AppColors.textPrim, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g. 8800123456, fastrefund@ybl',
              hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _loading ? null : _search,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          child: const Icon(Icons.search, size: 20),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Center(child: Padding(
      padding: EdgeInsets.only(top: 20),
      child: CircularProgressIndicator(color: AppColors.brand, strokeWidth: 3),
    ));
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
      ),
      child: Text(_error!, style: GoogleFonts.inter(color: AppColors.red, fontSize: 13)),
    );
  }

  Widget _buildGraphResult() {
    final graph = _graph!;
    if (graph.nodes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Text('No linked reports found for "${graph.query}".',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
      );
    }

    // Find the node that matches the query itself (the "hub"); fall back to
    // the most-connected node if nothing matches exactly.
    final queryLower = graph.query.toLowerCase();
    final hub = graph.nodes.firstWhere(
      (n) => n.value.toLowerCase() == queryLower,
      orElse: () => graph.nodes.reduce((a, b) => a.linkedReportCount >= b.linkedReportCount ? a : b),
    );
    final spokes = graph.nodes.where((n) => n.id != hub.id).toList()
      ..sort((a, b) => b.linkedReportCount.compareTo(a.linkedReportCount));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Linked to ${graph.reportCount} scam report${graph.reportCount == 1 ? '' : 's'} and ${spokes.length} other identifier${spokes.length == 1 ? '' : 's'}.',
                  style: GoogleFonts.inter(color: AppColors.textPrim, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(),
        const SizedBox(height: 20),

        // Hub node
        Center(child: _buildNodeChip(hub, isHub: true)),
        const SizedBox(height: 4),
        if (spokes.isNotEmpty)
          Center(
            child: Container(width: 2, height: 24, color: AppColors.border),
          ),
        const SizedBox(height: 4),

        // Spokes
        ...spokes.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.subdirectory_arrow_right, color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: _buildNodeChip(e.value)),
                ],
              ),
            ).animate().fadeIn(delay: (100 * e.key).ms).slideX(begin: -0.05, end: 0)),
      ],
    );
  }

  Widget _buildNodeChip(FraudNetworkNode node, {bool isHub = false}) {
    final color = _colorForType(node.type);
    return Container(
      width: isHub ? null : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isHub ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: isHub ? 1.5 : 1),
      ),
      child: Row(
        mainAxisSize: isHub ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Icon(_iconForType(node.type), color: color, size: isHub ? 22 : 18),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(node.typeLabel,
                    style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w600)),
                Text(node.value,
                    style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: isHub ? 15 : 13.5),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
            child: Text('${node.linkedReportCount}',
                style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
