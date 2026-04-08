import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/widgets/home/expanded_card/helpers/vibe_display.dart';

/// "How it feels" — vibe label, top-tag bars, and a wavy/bossman callout.
/// Returns SizedBox.shrink() when there's no vibe data on the location.
class VibeSection extends StatelessWidget {
  const VibeSection({super.key, required this.vibe});

  final VibeVector? vibe;

  @override
  Widget build(BuildContext context) {
    if (vibe == null || vibe!.values.isEmpty) {
      return const SizedBox.shrink();
    }

    final topVibes = vibe!.topTags(6);
    final maxVal = topVibes.isNotEmpty ? topVibes.first.value : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VIBE PROFILE',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PinitColors.aubergineSoft,
            letterSpacing: 0.12 * 11,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'How it feels',
          style: TextStyle(
            fontFamily: 'Rova',
            fontSize: 28,
            fontWeight: FontWeight.w100,
            color: PinitColors.aubergine,
            letterSpacing: 1.3,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 20),

        // Vibe bars — the strongest tag gets the accent treatment so the
        // page reveals "this is what this place feels like, mostly" at a
        // glance, instead of presenting a flat list of equal bars.
        ...topVibes.asMap().entries.map((e) {
          final entry = e.value;
          return _VibeBar(
            tag: entry.key,
            value: entry.value,
            max: maxVal,
            isLead: e.key == 0,
          );
        }),

        // Wavy / bossman callout
        if (vibe!.wavyScore >= 0.35) ...[
          const SizedBox(height: 12),
          const _VibeCallout(
            emoji: '✨',
            title: 'This spot has wavy energy',
            subtitle: 'Novel, interesting, worth discovering',
            isWavy: true,
          ),
        ] else if (vibe!.bossmanScore >= 0.35) ...[
          const SizedBox(height: 12),
          const _VibeCallout(
            emoji: '🏪',
            title: 'Classic bossman joint',
            subtitle: 'Reliable, familiar, no-frills',
            isWavy: false,
          ),
        ],
      ],
    );
  }
}

class _VibeBar extends StatelessWidget {
  const _VibeBar({
    required this.tag,
    required this.value,
    required this.max,
    this.isLead = false,
  });

  final String tag;
  final double value;
  final double max;

  /// True when this is the strongest vibe tag for the location.
  /// Lead bars get the accent fill + bolder label, the rest stay
  /// aubergine. Creates a visible hierarchy in what was a flat list.
  final bool isLead;

  @override
  Widget build(BuildContext context) {
    final icon = vibeIcons[tag] ?? Icons.label_rounded;
    final ratio = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    final barColor =
        isLead ? PinitColors.accent : PinitColors.aubergine;
    final labelWeight = isLead ? FontWeight.w700 : FontWeight.w500;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Icon(icon, size: 16, color: PinitColors.aubergineSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vibeDisplayName(tag),
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: labelWeight,
                      color: PinitColors.aubergine,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: isLead ? 10 : 8,
                      decoration: BoxDecoration(
                        color: PinitColors.creamDeep,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: isLead ? 10 : 8,
                      width: constraints.maxWidth * ratio,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 32,
            child: Text(
              '${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isLead ? PinitColors.accent : PinitColors.aubergineSoft,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeCallout extends StatelessWidget {
  const _VibeCallout({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isWavy,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool isWavy;

  @override
  Widget build(BuildContext context) {
    final accentColor = isWavy ? PinitColors.accent : PinitColors.aubergine;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: PinitColors.aubergineSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
