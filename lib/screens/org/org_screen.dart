import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show AppColors;
import '../../services/api_service.dart';

class OrgScreen extends StatefulWidget {
  const OrgScreen({super.key});
  @override
  State<OrgScreen> createState() => _OrgScreenState();
}

class _OrgScreenState extends State<OrgScreen> {
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>>? _members;
  bool _loading = true;
  bool _hasOrg = false;

  @override
  void initState() {
    super.initState();
    _hasOrg = context.read<ApiService>().currentUser?.organizationId != null;
    if (_hasOrg) _load();
    else _loading = false;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final dashboard = await api.getOrgDashboard();
      final members = await api.getOrgMembers();
      if (!mounted) return;
      setState(() { _dashboard = dashboard; _members = members; });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrg() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Create organization', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
        content: TextField(controller: nameCtrl, style: const TextStyle(color: AppColors.textPrim),
            decoration: const InputDecoration(labelText: 'Organization name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      await context.read<ApiService>().createOrganization(nameCtrl.text.trim());
      if (!mounted) return;
      setState(() => _hasOrg = true);
      _load();
    }
  }

  Future<void> _invite() async {
    final emailCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Invite team member', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
        content: TextField(controller: emailCtrl, style: const TextStyle(color: AppColors.textPrim),
            decoration: const InputDecoration(labelText: 'Their email (must already have an account)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Invite')),
        ],
      ),
    );
    if (result == true && emailCtrl.text.trim().isNotEmpty) {
      try {
        await context.read<ApiService>().inviteToOrg(emailCtrl.text.trim());
        if (!mounted) return;
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator(color: AppColors.brand)));
    }

    if (!_hasOrg) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Organization')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.apartment_outlined, color: AppColors.textMuted, size: 48),
              const SizedBox(height: 16),
              Text("You're not part of an organization yet", style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Create one to monitor scam exposure across your whole team.',
                  textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _createOrg, child: const Text('Create organization')),
            ]),
          ),
        ),
      );
    }

    final totalScans = _dashboard?['total_scans'] ?? 0;
    final highRisk = _dashboard?['high_risk_count'] ?? 0;
    final byCategory = List<Map<String, dynamic>>.from(_dashboard?['by_category'] ?? []);
    final byMember = List<Map<String, dynamic>>.from(_dashboard?['by_member'] ?? []);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Enterprise Dashboard'), actions: [
        IconButton(icon: const Icon(Icons.person_add_outlined), onPressed: _invite),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.brand,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(child: _statCard('Total Scans', '$totalScans', AppColors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('High Risk', '$highRisk', AppColors.red)),
            ]),
            const SizedBox(height: 20),
            Text('Scam categories detected', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (byCategory.isEmpty)
              Text('No scans yet', style: GoogleFonts.inter(color: AppColors.textMuted))
            else
              ...byCategory.map((c) => _barRow(c['category'], c['count'], totalScans)),
            const SizedBox(height: 20),
            Text('Team members (${_members?.length ?? 0})', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...byMember.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    Expanded(child: Text(m['name'] ?? m['email'], style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w600))),
                    Text('${m['scans']} scans', style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 12)),
                    const SizedBox(width: 10),
                    if ((m['high_risk'] ?? 0) > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text('${m['high_risk']} high-risk', style: GoogleFonts.inter(color: AppColors.red, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                )),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w900, fontSize: 26)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
      ]),
    );
  }

  Widget _barRow(String label, int count, int total) {
    final fraction = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13))),
          Text('$count', style: GoogleFonts.inter(color: AppColors.textPrim, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: fraction, backgroundColor: AppColors.surface2, color: AppColors.orange, minHeight: 6),
        ),
      ]),
    );
  }
}
