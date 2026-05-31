import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/widgets/home/expanded_card/helpers/match_result.dart';
import 'package:login/widgets/home/expanded_card/helpers/vibe_display.dart';

/// Floating "Match" banner that overlaps the bottom of the hero image.
/// Renders an animated progress ring driven by [matchAnim] (parent owned).
class MatchBannerSection extends StatelessWidget {
  const MatchBannerSection({
    super.key,
    required this.match,
    required this.matchAnim,
  });

  final MatchResult match;
  final Animation<double> matchAnim;

  @override
  Widget build(BuildContext context) {
    // ≥60% earns the accent treatment so the page shouts when there's a
    // genuinely strong match. Below that, the banner stays calm
    // aubergine — no false positives for "Okay match" / "New vibe".
    final isStrongMatch = match.score >= 0.60;
    final ringColor =
        isStrongMatch ? PinitColors.accent : PinitColors.aubergine;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      transform: Matrix4.translationValues(0, -28, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
        boxShadow: PinitColors.cardShadow,
      ),
      child: Row(
        children: [
          // Animated ring
          AnimatedBuilder(
            animation: matchAnim,
            builder: (_, __) => SizedBox(
              width: 60,
              height: 60,
              child: CustomPaint(
                painter: MatchRingPainter(
                  progress: matchAnim.value * match.score,
                  color: ringColor,
                  trackColor: PinitColors.creamDeep,
                  strokeWidth: 6.0,
                ),
                child: Center(
                  child: Text(
                    '${(matchAnim.value * match.percent).round()}%',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ringColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'MATCH',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PinitColors.aubergineSoft,
                        letterSpacing: 0.12 * 11,
                      ),
                    ),
                    if (isStrongMatch) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: PinitColors.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'STRONG',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: PinitColors.cream,
                            letterSpacing: 0.15 * 9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  match.label,
                  style: const TextStyle(
                    fontFamily: 'Rova',
                    fontFamilyFallback: ['Naria'],
                    fontSize: 20,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.2,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  match.topContributors.isNotEmpty
                      ? 'Based on ${match.topContributors.take(3).map((e) => vibeDisplayName(e.key).toLowerCase()).join(', ')}'
                      : 'Save more places to improve matching',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: PinitColors.mute,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (match.dietaryMatch != null)
            _DietaryBadge(ratio: match.dietaryMatch!),
        ],
      ),
    );
  }
}

class _DietaryBadge extends StatelessWidget {
  const _DietaryBadge({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final ok = ratio >= 0.8;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 14,
            color: ok ? PinitColors.aubergine : PinitColors.accent,
          ),
          const SizedBox(width: 5),
          Text(
            ok ? 'DIET ✓' : 'DIET ~',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: ok ? PinitColors.aubergine : PinitColors.accent,
              letterSpacing: 0.15 * 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the circular match ring (track + animated arc).
class MatchRingPainter extends CustomPainter {
  final double progress; // 0.0–1.0
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  MatchRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Track
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Arc
    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(MatchRingPainter old) =>
      old.progress != progress || old.color != color;
}
