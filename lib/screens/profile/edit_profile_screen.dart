import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show AppColors;
import '../../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _photoCtrl;
  bool _saving = false;
  bool _sendingVerification = false;
  String? _devVerifyToken;

  @override
  void initState() {
    super.initState();
    final user = context.read<ApiService>().currentUser;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _photoCtrl = TextEditingController(text: user?.photoUrl ?? '');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().updateProfile({
        'name': _nameCtrl.text.trim(),
        'photo_url': _photoCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendVerification() async {
    setState(() => _sendingVerification = true);
    try {
      final token = await context.read<ApiService>().sendVerificationEmail();
      if (!mounted) return;
      setState(() => _devVerifyToken = token);
    } finally {
      if (mounted) setState(() => _sendingVerification = false);
    }
  }

  Future<void> _verifyWithToken() async {
    if (_devVerifyToken == null) return;
    try {
      await context.read<ApiService>().verifyEmail(_devVerifyToken!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified!'), backgroundColor: AppColors.green),
        );
        setState(() => _devVerifyToken = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<ApiService>().currentUser;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrim),
              decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: AppColors.textSec)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _photoCtrl,
              style: const TextStyle(color: AppColors.textPrim),
              decoration: const InputDecoration(
                labelText: 'Profile photo URL', labelStyle: TextStyle(color: AppColors.textSec),
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              enabled: false,
              controller: TextEditingController(text: user?.email ?? ''),
              style: const TextStyle(color: AppColors.textMuted),
              decoration: const InputDecoration(labelText: 'Email (cannot be changed)', labelStyle: TextStyle(color: AppColors.textSec)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Save changes'),
            ),
            if (user != null && !user.isEmailVerified) ...[
              const SizedBox(height: 28),
              const Divider(color: AppColors.border),
              const SizedBox(height: 16),
              Text('Verify your email', style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('No email provider is configured for this demo build, so verification works via a token shown directly in the app.',
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12.5)),
              const SizedBox(height: 12),
              if (_devVerifyToken == null)
                OutlinedButton(
                  onPressed: _sendingVerification ? null : _sendVerification,
                  child: _sendingVerification
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrim))
                      : const Text('Send verification'),
                )
              else
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                    child: Text(_devVerifyToken!, style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 11)),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: _verifyWithToken, child: const Text('Confirm verification')),
                ]),
            ],
          ],
        ),
      ),
    );
  }
}
