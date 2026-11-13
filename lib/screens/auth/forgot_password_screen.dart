import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../main.dart' show AppColors;
import '../../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;
  String? _devOtp;
  String? _error;
  String? _success;

  Future<void> _requestOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await context.read<ApiService>().requestOtp(email, 'reset');
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _devOtp = res['dev_otp']?.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final otp = _otpCtrl.text.trim();
    final pw = _newPasswordCtrl.text;
    if (otp.length != 6 || pw.length < 8) {
      setState(() => _error = 'Enter a 6-digit OTP and a password (min 8 chars).');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<ApiService>().resetPasswordOtp(_emailCtrl.text.trim(), otp, pw);
      if (!mounted) return;
      setState(() => _success = 'Password updated. You can sign in now.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) _banner(_error!, AppColors.red, Icons.error_outline),
              if (_success != null) _banner(_success!, AppColors.green, Icons.check_circle_outline),
              if (!_otpSent) ...[
                Text('Enter your email and we will send a 6-digit reset code.',
                    style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 14)),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrim),
                  decoration: const InputDecoration(
                    labelText: 'Email', labelStyle: TextStyle(color: AppColors.textSec),
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _requestOtp,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Send reset code'),
                ),
              ] else ...[
                if (_devOtp != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'No email provider is configured yet, so here is your reset code directly '
                      'for testing:\n\n$_devOtp',
                      style: GoogleFonts.inter(color: AppColors.yellow, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Enter the 6-digit code sent to your email and your new password.',
                    style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 14)),
                const SizedBox(height: 16),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrim, letterSpacing: 8),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: '6-digit code', labelStyle: TextStyle(color: AppColors.textSec),
                    prefixIcon: Icon(Icons.vpn_key_outlined, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _newPasswordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrim),
                  decoration: const InputDecoration(
                    labelText: 'New password', labelStyle: TextStyle(color: AppColors.textSec),
                    prefixIcon: Icon(Icons.lock_outline, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Update password'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(String msg, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.inter(color: color, fontSize: 13))),
      ]),
    );
  }
}
