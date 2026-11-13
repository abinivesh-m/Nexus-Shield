import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show AppColors, AuthGate;
import '../widgets/ui.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _pulse;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.0, 0.62, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 0.38, curve: Curves.easeOut),
    );
    _textFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.32, 0.72, curve: Curves.easeOut),
    );
    _taglineFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.52, 0.92, curve: Curves.easeOut),
    );

    Future.delayed(const Duration(milliseconds: 2700), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('onboarding_done') ?? false;
      if (!mounted) return;
      final next = seen ? const AuthGate() : const OnboardingScreen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => next,
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 550),
        ),
      );
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: _enter,
                builder: (context, _) {
                  return Opacity(
                    opacity: _logoFade.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _Rings(pulse: _pulse),
                          const BrandLogo(size: 116),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 34),
              FadeTransition(
                opacity: _textFade,
                child: Column(
                  children: [
                    const BrandWordmark(size: 33, showMark: false),
                    const SizedBox(height: 10),
                    Text(
                      'AI-Powered Scam Protection',
                      style: GoogleFonts.inter(
                        color: AppColors.textSec,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 46),
              FadeTransition(
                opacity: _taglineFade,
                child: _Loader(progress: _enter),
              ),
              const Spacer(flex: 4),
              FadeTransition(
                opacity: _taglineFade,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Built in India  ·  Protecting every conversation',
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rings extends StatelessWidget {
  final Animation<double> pulse;
  const _Rings({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final t = pulse.value;
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(3, (i) {
              final p = (t + i / 3) % 1.0;
              final size = 116 + 118 * p;
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.22 * (1 - p)),
                    width: 1.4,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _Loader extends StatelessWidget {
  final Animation<double> progress;
  const _Loader({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (_, __) {
        return Column(
          children: [
            SizedBox(
              width: 132,
              height: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.08)),
                    FractionallySizedBox(
                      widthFactor: progress.value.clamp(0.05, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.brandGradient,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Starting secure session…',
              style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ],
        );
      },
    );
  }
}
