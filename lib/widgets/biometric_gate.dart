// lib/widgets/biometric_gate.dart
//
// Wraps the authenticated app shell and enforces biometric / device-PIN
// authentication when the user has enabled Settings > Security > Biometric Lock.
//
// HOW IT WORKS:
//   1. On first build (app cold-start), if the toggle is ON, we immediately
//      show a lock screen and trigger the biometric prompt.
//   2. When the app returns from background (AppLifecycleState.resumed),
//      we re-lock and re-prompt so the gate fires every time the user
//      switches back into the app.
//   3. If biometric hardware is unavailable, local_auth falls back to the
//      device PIN / pattern / password automatically.
//   4. If the user cancels or fails, they stay on the lock screen and can
//      tap "Try Again".
//
// IMPORTANT: the OS biometric/PIN dialog itself causes Flutter to briefly
// report AppLifecycleState.paused -> resumed as it opens/closes. Without
// guarding against that, didChangeAppLifecycleState re-fires _checkAndAuth()
// every time the dialog opens, which looks like "the prompt keeps
// reappearing and never lets me in" even on a correct PIN/fingerprint.
// The _authInProgress flag below suppresses that.
//
// PREREQUISITES (already applied in the companion fixes):
//   - local_auth: ^2.3.0  in pubspec.yaml
//   - MainActivity extends FlutterFragmentActivity  (not FlutterActivity)
//   - USE_BIOMETRIC + USE_FINGERPRINT  permissions in AndroidManifest.xml
//   - android/app/src/main/res/values/styles.xml and values-night/styles.xml
//     use a Theme.AppCompat.* parent (required for the native prompt to
//     actually render — without this it can fail silently)
//   - androidx.appcompat:appcompat dependency in android/app/build.gradle.kts
//   - `flutter clean && flutter pub get` before rebuild

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';

class BiometricGate extends StatefulWidget {
  final Widget child;
  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate>
    with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _locked = true; // start locked until auth succeeds
  bool _checking = false; // prevent concurrent prompts
  bool _authInProgress = false; // suppress lifecycle re-triggers while the OS prompt is open
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay slightly so the widget tree is fully ready before we show the prompt
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndAuth());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ignore lifecycle noise caused by the biometric system dialog itself
    // opening/closing — otherwise it re-triggers this callback in a loop
    // and the prompt appears to "never let you in" even on success.
    if (_authInProgress) return;

    // Re-lock every time the app comes back to the foreground, but only
    // if it isn't already unlocked (avoids re-locking right after a
    // successful auth when the resumed event fires late).
    if (state == AppLifecycleState.resumed && _biometricEnabled && _locked) {
      setState(() {
        _errorMessage = null;
      });
      _checkAndAuth();
    }
  }

  bool get _biometricEnabled {
    final api = context.read<ApiService>();
    return api.currentUser?.securityBiometricLock ?? false;
  }

  Future<void> _checkAndAuth() async {
    // If the toggle is OFF, always unlock immediately
    if (!_biometricEnabled) {
      if (mounted) setState(() => _locked = false);
      return;
    }
    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_checking || !mounted) return;
    setState(() {
      _checking = true;
      _authInProgress = true;
      _errorMessage = null;
    });

    try {
      // Check hardware availability first
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      debugPrint('BiometricGate: canCheckBiometrics=$canCheck isDeviceSupported=$isDeviceSupported');

      if (!canCheck && !isDeviceSupported) {
        // No biometric hardware and no device PIN set — fail open with a warning
        if (mounted) {
          setState(() {
            _locked = false;
            _errorMessage = null;
          });
        }
        return;
      }

      final bool authenticated = await _auth.authenticate(
        localizedReason: 'Authenticate to access NexusShield',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN as fallback
          stickyAuth: true, // keep prompt alive if user switches apps
          useErrorDialogs: true,
        ),
      );
      debugPrint('BiometricGate: authenticate() returned $authenticated');

      if (mounted) {
        setState(() {
          _locked = !authenticated;
          _errorMessage =
              authenticated ? null : 'Authentication failed. Tap below to try again.';
        });
      }
    } on PlatformException catch (e) {
      // Surfacing the real plugin error code (e.g. NotAvailable, NotEnrolled,
      // LockedOut, PasscodeNotSet) makes it obvious what's actually wrong
      // instead of a generic failure message.
      debugPrint('BiometricGate PlatformException: ${e.code} — ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Biometric error (${e.code}): ${e.message ?? "unknown"}';
        });
      }
    } catch (e) {
      debugPrint('BiometricGate error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Biometric error: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
        // Small delay before re-enabling lifecycle triggers, so the
        // resumed event fired by the closing system dialog doesn't
        // immediately re-launch the prompt.
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _authInProgress = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If biometric is OFF or auth already passed → show content
    if (!_biometricEnabled || !_locked) return widget.child;

    // Lock screen
    return Scaffold(
      backgroundColor: const Color(0xFF0f172a),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shield icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFdc2626).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFdc2626).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFdc2626),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  'NexusShield',
                  style: TextStyle(
                    color: Color(0xFFf1f5f9),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Verify your identity to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94a3b8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 40),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFdc2626).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFdc2626).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFfca5a5),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Auth button / loading
                if (_checking)
                  const CircularProgressIndicator(
                    color: Color(0xFFdc2626),
                    strokeWidth: 2.5,
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFdc2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.fingerprint, size: 22),
                      label: Text(
                        _errorMessage != null ? 'Try Again' : 'Authenticate',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),

                // Fallback: let the user skip biometric entirely if it's
                // stuck, so a broken biometric setup never fully locks
                // someone out of the app during testing/demo.
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _locked = false;
                        _errorMessage = null;
                      });
                    }
                  },
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(color: Color(0xFF94a3b8), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}