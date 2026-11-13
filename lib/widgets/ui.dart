import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart' show AppColors;

/// ─────────────────────────────────────────────────────────────────────────
/// Aurora background
/// A slow, GPU-cheap moving gradient that gives every hero surface depth
/// without shipping a single image.
/// ─────────────────────────────────────────────────────────────────────────
class AuroraBackground extends StatefulWidget {
  final Widget child;
  final bool subtle;

  const AuroraBackground({super.key, required this.child, this.subtle = false});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(
                painter: _AuroraPainter(_c.value, subtle: widget.subtle),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final bool subtle;

  _AuroraPainter(this.t, {required this.subtle});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    final a = subtle ? 0.55 : 1.0;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, h),
          const [Color(0xFF0B1222), Color(0xFF070B14), Color(0xFF05070E)],
          const [0.0, 0.55, 1.0],
        ),
    );

    void blob(double cx, double cy, double r, Color color) {
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(cx, cy),
            r,
            [color.withValues(alpha: color.a * a), color.withValues(alpha: 0)],
            const [0.0, 1.0],
          ),
      );
    }

    final p = t * 2 * math.pi;
    blob(
      w * (0.16 + 0.06 * math.sin(p)),
      h * (0.14 + 0.04 * math.cos(p * 0.8)),
      w * 0.78,
      const Color(0x2EF43F5E),
    );
    blob(
      w * (0.92 + 0.04 * math.cos(p * 0.7 + 1.2)),
      h * (0.34 + 0.05 * math.sin(p * 0.9)),
      w * 0.70,
      const Color(0x26F97316),
    );
    blob(
      w * (0.48 + 0.08 * math.sin(p * 0.6 + 2.4)),
      h * (0.92 + 0.03 * math.cos(p * 0.5)),
      w * 0.85,
      const Color(0x223B82F6),
    );

    // bottom vignette keeps content readable over the glow
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.55),
          Offset(0, h),
          const [Color(0x00070B14), Color(0xCC070B14)],
          const [0.0, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.t != t || old.subtle != subtle;
}

/// ─────────────────────────────────────────────────────────────────────────
/// Pressable — scale + haptic feedback on tap. Makes every surface feel alive.
/// ─────────────────────────────────────────────────────────────────────────
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.975,
    this.borderRadius,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap!.call();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// GlassCard — the core surface of the app.
/// ─────────────────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? accent;
  final VoidCallback? onTap;
  final bool glow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.accent,
    this.onTap,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = accent;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
                (a ?? Colors.white).withValues(alpha: a == null ? 0.055 : 0.10),
                AppColors.surface),
            AppColors.surface.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: a == null
              ? Colors.white.withValues(alpha: 0.07)
              : a.withValues(alpha: 0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          if (glow && a != null)
            BoxShadow(
              color: a.withValues(alpha: 0.16),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap, child: card);
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// GradientButton — primary call to action.
/// ─────────────────────────────────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final Gradient? gradient;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expand = true,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Pressable(
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          decoration: BoxDecoration(
            gradient: gradient ?? AppColors.brandGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.red.withValues(alpha: 0.34),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else ...[
                if (icon != null) ...[
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// SectionHeader
/// ─────────────────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppColors.textPrim,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// StatusPill
/// ─────────────────────────────────────────────────────────────────────────
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool pulse;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse)
            _PulseDot(color: color)
          else if (icon != null)
            Icon(icon, size: 12, color: color),
          if (pulse || icon != null) const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final v = _c.value;
        return SizedBox(
          width: 10,
          height: 10,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 4 + 8 * v,
                height: 4 + 8 * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.45 * (1 - v)),
                ),
              ),
              Container(
                width: 5,
                height: 5,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// StatTile — compact metric with an accent bar and a soft glow.
/// ─────────────────────────────────────────────────────────────────────────
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.12),
            AppColors.surface.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 5),
          ],
          Text(
            value,
            maxLines: 1,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// BrandLogo — the app mark, rendered from the generated asset.
/// ─────────────────────────────────────────────────────────────────────────
class BrandLogo extends StatelessWidget {
  final double size;
  final bool glow;

  const BrandLogo({super.key, this.size = 40, this.glow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.235),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.red.withValues(alpha: 0.35),
                  blurRadius: size * 0.55,
                  offset: Offset(0, size * 0.16),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.235),
        child: Image.asset(
          'assets/icon/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// BrandWordmark
/// ─────────────────────────────────────────────────────────────────────────
class BrandWordmark extends StatelessWidget {
  final double size;
  final bool showMark;

  const BrandWordmark({super.key, this.size = 20, this.showMark = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMark) ...[
          BrandLogo(size: size * 1.55, glow: false),
          SizedBox(width: size * 0.55),
        ],
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Nexus',
                style: GoogleFonts.inter(
                  color: AppColors.textPrim,
                  fontSize: size,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              TextSpan(
                text: 'Shield',
                style: GoogleFonts.inter(
                  color: AppColors.red,
                  fontSize: size,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
