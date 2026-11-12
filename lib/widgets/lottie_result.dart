import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show AppColors;

/// Animated result overlay — shows scanning/success/danger state
class LottieResult extends StatelessWidget {
  final LottieState state;
  final String? message;

  const LottieResult({super.key, required this.state, this.message});

  @override
  Widget build(BuildContext context) {
    final config = _configs[state]!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Lottie.asset(
            config.path,
            repeat: config.repeat,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              config.fallback,
              color: config.color,
              size: 64,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            style: GoogleFonts.inter(
              color: config.color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  static const _configs = {
    LottieState.scanning: _Config(
      path: 'assets/lottie/scanning.json',
      fallback: Icons.radar_rounded,
      color: AppColors.blue,
      repeat: true,
    ),
    LottieState.success: _Config(
      path: 'assets/lottie/success.json',
      fallback: Icons.check_circle_outline_rounded,
      color: AppColors.green,
      repeat: false,
    ),
    LottieState.danger: _Config(
      path: 'assets/lottie/danger.json',
      fallback: Icons.warning_amber_rounded,
      color: AppColors.red,
      repeat: true,
    ),
  };
}

enum LottieState { scanning, success, danger }

class _Config {
  final String path;
  final IconData fallback;
  final Color color;
  final bool repeat;
  const _Config({
    required this.path,
    required this.fallback,
    required this.color,
    required this.repeat,
  });
}

/// Empty state widget with Lottie animation
class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Lottie.asset(
                'assets/lottie/empty.json',
                repeat: true,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.inbox_outlined,
                  color: AppColors.textMuted,
                  size: 72,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.inter(
                color: AppColors.textPrim,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: AppColors.textSec,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                ),
                child: Text(
                  actionLabel!,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
