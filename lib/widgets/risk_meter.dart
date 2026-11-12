import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RiskMeter extends StatelessWidget {
  final int score;
  final Color color;

  const RiskMeter({super.key, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 7,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: GoogleFonts.inter(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              Text(
                '%',
                style: GoogleFonts.inter(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
