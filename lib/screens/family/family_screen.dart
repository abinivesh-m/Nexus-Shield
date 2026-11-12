import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show AppColors;
import '../../models/models.dart';
import '../../services/api_service.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  List<FamilyMember>? _members;
  List<Map<String, dynamic>> _alerts = [];
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
      final members = await api.getFamilyMembers();
      final alerts = await api.getFamilyAlerts();
      if (!mounted) return;
      setState(() { _members = members; _alerts = alerts; });
    } catch (_) {
      if (mounted) setState(() => _members = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    final emailCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Add family member', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: emailCtrl, style: const TextStyle(color: AppColors.textPrim),
              decoration: const InputDecoration(labelText: 'Their email (must have a NexusShield account)')),
          const SizedBox(height: 10),
          TextField(controller: labelCtrl, style: const TextStyle(color: AppColors.textPrim),
              decoration: const InputDecoration(labelText: 'Label (e.g. "Mom", "Dad")')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (result == true && emailCtrl.text.trim().isNotEmpty) {
      try {
        await context.read<ApiService>().inviteFamilyMember(
              emailCtrl.text.trim(), labelCtrl.text.trim().isEmpty ? 'Family member' : labelCtrl.text.trim(),
            );
        if (!mounted) return;
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyError(e))),
          );
        }
      }
    }
  }

  Future<void> _remove(String linkId) async {
    await context.read<ApiService>().removeFamilyMember(linkId);
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Family Protection')),
      floatingActionButton: FloatingActionButton(
        onPressed: _invite, backgroundColor: AppColors.red,
        child: const Icon(Icons.person_add_outlined),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.red))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.red,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  Text('Watch over the people who matter', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("You'll be alerted when someone you're watching scans something high-risk.",
                      style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
                  const SizedBox(height: 18),
                  if ((_members ?? []).isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('No family members added yet', style: GoogleFonts.inter(color: AppColors.textMuted))),
                    )
                  else
                    ...(_members ?? []).map((m) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                          child: Row(children: [
                            CircleAvatar(backgroundColor: AppColors.blue.withValues(alpha: 0.15),
                                child: Text(m.memberLabel.isNotEmpty ? m.memberLabel[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.blue))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m.memberLabel, style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w600)),
                              if (m.memberEmail != null) Text(m.memberEmail!, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                            ])),
                            IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18), onPressed: () => _remove(m.id)),
                          ]),
                        )),
                  const SizedBox(height: 20),
                  Text('Recent alerts', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 10),
                  if (_alerts.isEmpty)
                    Text('No alerts yet', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13))
                  else
                    ..._alerts.map((a) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${a['member_label']} encountered a ${a['scam_type']} (risk ${a['risk_score']}%)',
                                style: GoogleFonts.inter(color: AppColors.textPrim, fontSize: 12.5))),
                          ]),
                        )),
                ],
              ),
            ),
    );
  }
}
