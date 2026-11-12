import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../main.dart' show AppColors, AuthGate;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardPage(
      lottie: 'assets/lottie/shield_protect.json',
      fallbackIcon: Icons.shield_outlined,
      iconColor: AppColors.red,
      title: 'Stay Protected\nFrom Scams',
      subtitle:
          'India loses ₹1.25 lakh crore to scams every year.\nNexusShield uses AI to protect you in real time.',
      badge: '🇮🇳 Made for India',
    ),
    _OnboardPage(
      lottie: 'assets/lottie/scanning.json',
      fallbackIcon: Icons.manage_search_rounded,
      iconColor: AppColors.blue,
      title: 'Scan Anything\nInstantly',
      subtitle:
          'Suspicious SMS? Fake website? Scam call?\nPaste it, screenshot it, or type it — AI analyzes in seconds.',
      badge: '⚡ Powered by Gemini AI',
    ),
    _OnboardPage(
      lottie: 'assets/lottie/success.json',
      fallbackIcon: Icons.people_alt_outlined,
      iconColor: AppColors.green,
      title: 'Protect Your\nEntire Family',
      subtitle:
          'Add family members and get alerts when they\nencounter scams. Community-powered protection.',
      badge: '👨‍👩‍👧‍👦 Family Protection',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
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
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 20, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.inter(
                      color: AppColors.textSec,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _pages[i],
              ),
            ),

            // Bottom section
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
              child: Column(
                children: [
                  // Page indicator
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      activeDotColor: AppColors.red,
                      dotColor: AppColors.border,
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_page < _pages.length - 1) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _finish();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _page < _pages.length - 1
                            ? 'Continue'
                            : 'Get Protected — It\'s Free',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),

                  if (_page == _pages.length - 1) ...[
                    const SizedBox(height: 16),
                    Text(
                      'No credit card. No ads. Free forever.',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final String lottie;
  final IconData fallbackIcon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;

  const _OnboardPage({
    required this.lottie,
    required this.fallbackIcon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animation
          SizedBox(
            width: 220,
            height: 220,
            child: Lottie.asset(
              lottie,
              repeat: true,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                fallbackIcon,
                color: iconColor,
                size: 100,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              badge,
              style: GoogleFonts.inter(
                color: AppColors.textSec,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.textPrim,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: AppColors.textSec,
              fontSize: 15,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
