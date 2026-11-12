import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart' show AppColors;
import '../services/api_service.dart';

/// Phase 3 - Clipboard Monitor (in-app).
///
/// Wrap the main shell with this to check clipboard content whenever the
/// app resumes from the background (e.g. the user just copied a link/UPI ID
/// in another app and switched back). This is genuinely real-time *while
/// NexusShield has focus* -- true background monitoring needs a native
/// Android foreground service and the user's explicit runtime permission,
/// which isn't something a cross-platform Flutter widget can do on its own.
class ClipboardMonitor extends StatefulWidget {
  final Widget child;
  const ClipboardMonitor({super.key, required this.child});

  @override
  State<ClipboardMonitor> createState() => _ClipboardMonitorState();
}

class _ClipboardMonitorState extends State<ClipboardMonitor> with WidgetsBindingObserver {
  String? _lastChecked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    final api = context.read<ApiService>();
    if (!api.isAuthenticated) return;
    if (!(api.currentUser?.securityAutoScanClipboard ?? true)) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final content = data?.text?.trim();
    if (content == null || content.isEmpty || content == _lastChecked) return;
    _lastChecked = content;

    try {
      final result = await api.checkClipboard(content);
      if (result['is_relevant'] == true && mounted) {
        final riskScore = result['risk_score'] ?? 0;
        if (riskScore >= 50 || result['matched_known_scam'] == true) {
          _showWarning(content, result);
        }
      }
    } catch (_) {
      // Silent failure -- clipboard checks should never interrupt the user
      // with an error if the backend is briefly unreachable.
    }
  }

  void _showWarning(String content, Map<String, dynamic> result) {
    final matched = result['matched_known_scam'] == true;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(matched ? Icons.dangerous : Icons.warning_amber_rounded,
                  color: matched ? AppColors.red : AppColors.orange, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(
                  matched ? 'Known scam detected in clipboard' : 'Suspicious clipboard content',
                  style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w800, fontSize: 16))),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
              child: Text(content, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 12.5)),
            ),
            const SizedBox(height: 10),
            Text(result['advice'] ?? 'Double-check this before using it anywhere.',
                style: GoogleFonts.inter(color: AppColors.textSec, fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it'),
            )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
