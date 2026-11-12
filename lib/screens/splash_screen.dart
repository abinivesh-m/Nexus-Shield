import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show AppColors, AuthGate;
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
    );

    _controller.forward();

    // Navigate after animation
    Future.delayed(const Duration(milliseconds: 3000), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('onboarding_done') ?? false;
      if (!mounted) return;
      if (!seen) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const OnboardingScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
        return;
      }
      // AuthGate reactively watches ApiService.isAuthenticated and shows
      // LoginScreen or MainShell accordingly -- and keeps watching, so a
      // successful login/signup from LoginScreen correctly routes forward
      // instead of dead-ending (that dead-end was the original bug: this
      // used to push straight to LoginScreen, which has no way to react
      // to a later successful auth call).
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthGate(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shield animation
                Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: Opacity(
                    opacity: _fadeIn.value,
                    child: SizedBox(
                      width: 160,
                      height: 160,
                      child: Lottie.asset(
                        'assets/lottie/shield_protect.json',
                        repeat: true,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield,
                          color: AppColors.red,
                          size: 100,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // App name
                Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: Opacity(
                    opacity: _fadeIn.value,
                    child: Text(
                      'NexusShield',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrim,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Tagline
                Opacity(
                  opacity: _taglineFade.value,
                  child: Text(
                    'AI-Powered Scam Protection',
                    style: GoogleFonts.inter(
                      color: AppColors.textSec,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 80),
                // Loading dots
                Opacity(
                  opacity: _taglineFade.value,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (_, __) {
                          final delay = i * 0.15;
                          final t = ((_controller.value - delay) * 3)
                              .clamp(0.0, 1.0);
                          final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2)
                              .clamp(0.3, 1.0);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: opacity),
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
