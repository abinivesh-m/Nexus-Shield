import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show AppColors;
import '../../services/api_service.dart';
import '../reports/reports_screen.dart' show kScamCategories;

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: AppColors.orange,
          labelColor: AppColors.textPrim,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [Tab(text: 'Analytics'), Tab(text: 'Reports'), Tab(text: 'Scam DB'), Tab(text: 'Users')],
        ),
      ),
      body: TabBarView(controller: _tab, children: const [
        _AnalyticsTab(), _ReportsReviewTab(), _ScamDbTab(), _UsersTab(),
      ]),
    );
  }
}

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();
  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<ApiService>().adminAnalytics();
      if (!mounted) return;
      setState(() => _data = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    final categories = List<Map<String, dynamic>>.from(_data!['scans_by_category'] ?? []);
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5,
            children: [
              _stat('Total Users', '${_data!['total_users']}', Icons.people_outline, AppColors.blue),
              _stat('Total Scans', '${_data!['total_scans']}', Icons.search, AppColors.green),
              _stat('High Risk', '${_data!['high_risk_scans']}', Icons.warning_amber_rounded, AppColors.red),
              _stat('Pending Reports', '${_data!['pending_reports']}', Icons.flag_outlined, AppColors.yellow),
            ],
          ),
          const SizedBox(height: 8),
          _stat('Scam Database Size', '${_data!['scam_database_size']}', Icons.storage, AppColors.orange, wide: true),
          const SizedBox(height: 20),
          Text('Scans by category', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...categories.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: Text(c['category'], style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13))),
                  Text('${c['count']}', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color, {bool wide = false}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w900, fontSize: 20)),
        Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
      ]),
    );
  }
}

class _ReportsReviewTab extends StatefulWidget {
  const _ReportsReviewTab();
  @override
  State<_ReportsReviewTab> createState() => _ReportsReviewTabState();
}

class _ReportsReviewTabState extends State<_ReportsReviewTab> {
  List<Map<String, dynamic>>? _reports;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reports = await context.read<ApiService>().adminListReports(status: 'pending');
      if (!mounted) return;
      setState(() => _reports = reports);
    } catch (_) {
      if (mounted) setState(() => _reports = []);
    }
  }

  Future<void> _review(String id, String status) async {
    await context.read<ApiService>().adminReviewReport(id, status);
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_reports == null) return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    if (_reports!.isEmpty) {
      return Center(child: Text('No pending reports', style: GoogleFonts.inter(color: AppColors.textMuted)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports!.length,
        itemBuilder: (ctx, i) {
          final r = _reports![i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['category'] ?? 'Uncategorized', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if ((r['description'] ?? '').isNotEmpty)
                Text(r['description'], style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if ((r['website'] ?? '').isNotEmpty) _chip(r['website']),
                if ((r['phone_number'] ?? '').isNotEmpty) _chip(r['phone_number']),
                if ((r['upi_id'] ?? '').isNotEmpty) _chip(r['upi_id']),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => _review(r['id'], 'rejected'),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.textMuted)),
                  child: const Text('Reject'),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: () => _review(r['id'], 'verified'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
                  child: const Text('Verify'),
                )),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 11)),
      );
}

class _ScamDbTab extends StatefulWidget {
  const _ScamDbTab();
  @override
  State<_ScamDbTab> createState() => _ScamDbTabState();
}

class _ScamDbTabState extends State<_ScamDbTab> {
  List<Map<String, dynamic>>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await context.read<ApiService>().adminListScamDb();
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (_) {
      if (mounted) setState(() => _entries = []);
    }
  }

  Future<void> _addEntry() async {
    String entryType = 'domain';
    String severity = 'high';
    final valueCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Phishing');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Add scam DB entry', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: entryType, dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrim),
                items: const [
                  DropdownMenuItem(value: 'domain', child: Text('Domain')),
                  DropdownMenuItem(value: 'url', child: Text('URL')),
                  DropdownMenuItem(value: 'phone', child: Text('Phone number')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI ID')),
                ],
                onChanged: (v) => setLocal(() => entryType = v ?? 'domain'),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 10),
              TextField(controller: valueCtrl, style: const TextStyle(color: AppColors.textPrim),
                  decoration: const InputDecoration(labelText: 'Value')),
              const SizedBox(height: 10),
              TextField(controller: categoryCtrl, style: const TextStyle(color: AppColors.textPrim),
                  decoration: const InputDecoration(labelText: 'Category')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: severity, dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrim),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: (v) => setLocal(() => severity = v ?? 'high'),
                decoration: const InputDecoration(labelText: 'Severity'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        );
      }),
    );

    if (result == true && valueCtrl.text.trim().isNotEmpty) {
      if (!mounted) return;
      await context.read<ApiService>().adminAddScamDbEntry(
            entryType: entryType, value: valueCtrl.text.trim(),
            category: categoryCtrl.text.trim(), severity: severity,
          );
      if (!mounted) return;
      _load();
    }
  }

  Future<void> _delete(String id) async {
    await context.read<ApiService>().adminDeleteScamDbEntry(id);
    if (!mounted) return;
    _load();
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical': return AppColors.red;
      case 'high': return AppColors.orange;
      case 'medium': return AppColors.yellow;
      default: return AppColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_entries == null) return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(onPressed: _addEntry, backgroundColor: AppColors.orange, child: const Icon(Icons.add)),
      body: _entries!.isEmpty
          ? Center(child: Text('Scam database is empty', style: GoogleFonts.inter(color: AppColors.textMuted)))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.brand,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _entries!.length,
                itemBuilder: (ctx, i) {
                  final e = _entries![i];
                  final color = _severityColor(e['severity']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Row(children: [
                      Container(width: 8, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e['value'], style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('${e['entry_type']} • ${e['category']} • ${e['source']}', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                      ])),
                      IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20), onPressed: () => _delete(e['id'])),
                    ]),
                  );
                },
              ),
            ),
    );
  }
}

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<Map<String, dynamic>>? _users;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await context.read<ApiService>().adminListUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (_) {
      if (mounted) setState(() => _users = []);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete this user?', style: GoogleFonts.inter(color: AppColors.red, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: GoogleFonts.inter(color: AppColors.red))),
        ],
      ),
    );
    if (confirm == true) {
      if (!mounted) return;
      await context.read<ApiService>().adminDeleteUser(id);
      if (!mounted) return;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_users == null) return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users!.length,
        itemBuilder: (ctx, i) {
          final u = _users![i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.surface2,
                  child: Text((u['name'] ?? u['email'])[0].toUpperCase(), style: const TextStyle(color: AppColors.textPrim))),
              title: Text(u['name'] ?? u['email'], style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w600, fontSize: 13.5)),
              subtitle: Text(u['email'], style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11.5)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (u['is_admin'] == true)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('ADMIN', style: GoogleFonts.inter(color: AppColors.orange, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20), onPressed: () => _delete(u['id'])),
              ]),
            ),
          );
        },
      ),
    );
  }
}
