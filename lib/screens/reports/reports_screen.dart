import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show AppColors;
import '../../models/models.dart';
import '../../services/api_service.dart';

const List<String> kScamCategories = [
  'Phishing', 'OTP Scam', 'Job Scam', 'Loan Scam', 'UPI Fraud',
  'Digital Arrest Scam', 'Investment Scam', 'Romance Scam', 'Courier Scam',
  'Lottery Scam', 'Uncategorized',
];

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
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
        title: const Text('Scam Reporting'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.brand,
          labelColor: AppColors.textPrim,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [Tab(text: 'Submit a Report'), Tab(text: 'My Reports')],
        ),
      ),
      body: TabBarView(controller: _tab, children: const [_SubmitReportTab(), _MyReportsTab()]),
    );
  }
}

class _SubmitReportTab extends StatefulWidget {
  const _SubmitReportTab();
  @override
  State<_SubmitReportTab> createState() => _SubmitReportTabState();
}

class _SubmitReportTabState extends State<_SubmitReportTab> {
  final _websiteCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Uncategorized';
  XFile? _screenshot;
  bool _submitting = false;

  Future<void> _pickScreenshot() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600, maxHeight: 2400);
    if (picked != null) setState(() => _screenshot = picked);
  }

  Future<void> _submit() async {
    final hasAnyField = _websiteCtrl.text.trim().isNotEmpty ||
        _phoneCtrl.text.trim().isNotEmpty ||
        _upiCtrl.text.trim().isNotEmpty ||
        _descCtrl.text.trim().isNotEmpty ||
        _screenshot != null;
    if (!hasAnyField) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one detail: screenshot, website, phone, UPI ID, or description')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      String? base64Image;
      if (_screenshot != null) {
        final bytes = await _screenshot!.readAsBytes();
        base64Image = base64Encode(bytes);
      }
      await context.read<ApiService>().submitScamReport(
            screenshotBase64: base64Image,
            website: _websiteCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
            upiId: _upiCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            category: _category,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Our team will review it shortly.'), backgroundColor: AppColors.green),
        );
        setState(() {
          _websiteCtrl.clear(); _phoneCtrl.clear(); _upiCtrl.clear(); _descCtrl.clear();
          _screenshot = null; _category = 'Uncategorized';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Help protect others', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text('Verified reports get added to the live scam database that protects every NexusShield user.',
              style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickScreenshot,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, style: BorderStyle.solid),
              ),
              child: _screenshot == null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textMuted, size: 32),
                        const SizedBox(height: 8),
                        Text('Add screenshot (optional)', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                      ]),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(_screenshot!.path, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image, color: AppColors.textMuted)),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _field(_websiteCtrl, 'Website / domain', Icons.public),
          const SizedBox(height: 12),
          _field(_phoneCtrl, 'Phone number', Icons.call_outlined),
          const SizedBox(height: 12),
          _field(_upiCtrl, 'UPI ID', Icons.account_balance_wallet_outlined),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            dropdownColor: AppColors.surface,
            style: GoogleFonts.inter(color: AppColors.textPrim),
            decoration: const InputDecoration(
              labelText: 'Category', labelStyle: TextStyle(color: AppColors.textSec),
              prefixIcon: Icon(Icons.category_outlined, color: AppColors.textMuted),
            ),
            items: kScamCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v ?? 'Uncategorized'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            style: const TextStyle(color: AppColors.textPrim),
            decoration: const InputDecoration(
              labelText: 'Description', alignLabelWithHint: true, labelStyle: TextStyle(color: AppColors.textSec),
              hintText: 'What happened? Include any details that could help others recognize this scam.',
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Submit Report'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.textPrim),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: AppColors.textSec),
        prefixIcon: Icon(icon, color: AppColors.textMuted),
      ),
    );
  }
}

class _MyReportsTab extends StatefulWidget {
  const _MyReportsTab();
  @override
  State<_MyReportsTab> createState() => _MyReportsTabState();
}

class _MyReportsTabState extends State<_MyReportsTab> {
  List<ScamReport>? _reports;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final reports = await context.read<ApiService>().myReports();
      if (!mounted) return;
      setState(() => _reports = reports);
    } catch (_) {
      if (mounted) setState(() => _reports = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'verified': return AppColors.green;
      case 'rejected': return AppColors.red;
      default: return AppColors.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    if (_reports == null || _reports!.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.flag_outlined, color: AppColors.textMuted, size: 36),
          const SizedBox(height: 10),
          Text('No reports submitted yet', style: GoogleFonts.inter(color: AppColors.textSec)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports!.length,
        itemBuilder: (ctx, i) {
          final r = _reports![i];
          final statusColor = _statusColor(r.status);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.category, style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(r.status.toUpperCase(), style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ]),
              if (r.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(r.description, style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (r.website.isNotEmpty || r.phoneNumber.isNotEmpty || r.upiId.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (r.website.isNotEmpty) _chip(r.website, Icons.public),
                  if (r.phoneNumber.isNotEmpty) _chip(r.phoneNumber, Icons.call_outlined),
                  if (r.upiId.isNotEmpty) _chip(r.upiId, Icons.account_balance_wallet_outlined),
                ]),
              ],
            ]),
          );
        },
      ),
    );
  }

  Widget _chip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 11)),
      ]),
    );
  }
}
