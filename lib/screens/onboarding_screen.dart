import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../main.dart' show AppColors, AuthGate;
import '../widgets/ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardPage(
      icon: Icons.shield_rounded,
      iconColor: AppColors.red,
      title: 'Stay protected\nfrom scams',
      subtitle:
          'India loses over ₹1.25 lakh crore to scams every year.\nNexusShield uses AI to protect you in real time.',
      badge: '🇮🇳  Made for India',
    ),
    _OnboardPage(
      icon: Icons.manage_search_rounded,
      iconColor: AppColors.blue,
      title: 'Scan anything\ninstantly',
      subtitle:
          'Suspicious SMS? Fake website? Scam call?\nPaste it, screenshot it, or type it — AI analyzes in seconds.',
      badge: '⚡  Powered by Gemini AI',
    ),
    _OnboardPage(
      icon: Icons.family_restroom_rounded,
      iconColor: AppColors.green,
      title: 'Protect your\nwhole family',
      subtitle:
          'Add family members and get alerts when they\nencounter scams. Community-powered protection.',
      badge: '👨‍👩‍👧‍👦  Family protection',
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
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 14, 0),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        color: AppColors.textSec,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _pages[i],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                child: Column(
                  children: [
                    SmoothPageIndicator(
                      controller: _controller,
                      count: _pages.length,
                      effect: ExpandingDotsEffect(
                        activeDotColor: AppColors.red,
                        dotColor: Colors.white.withValues(alpha: 0.14),
                        dotHeight: 7,
                        dotWidth: 7,
                        expansionFactor: 3.4,
                        spacing: 6,
                      ),
                    ),
                    const SizedBox(height: 26),
                    GradientButton(
                      label: isLast ? 'Get protected — it\'s free' : 'Continue',
                      icon: isLast
                          ? Icons.shield_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: () {
                        if (!isLast) {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          _finish();
                        }
                      },
                    ),
                    AnimatedOpacity(
                      opacity: isLast ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          'No credit card. No ads. Free forever.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;

  const _OnboardPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(48),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withValues(alpha: 0.30),
                  iconColor.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: iconColor.withValues(alpha: 0.32)),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.28),
                  blurRadius: 46,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 72),
          ),
          const SizedBox(height: 34),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: Text(
              badge,
              style: GoogleFonts.inter(
                color: AppColors.textSec,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textPrim,
              fontSize: 31,
              fontWeight: FontWeight.w900,
              height: 1.14,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppColors.textSec,
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
