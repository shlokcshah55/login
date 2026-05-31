import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/widgets/home/expanded_card/helpers/vibe_display.dart';

/// "Why go" — first editorial body section in the redesigned restaurant
/// expanded card. Merges the previous `AboutSection` (human-language
/// summary) with the highest-value vibe rationale: a wavy/bossman
/// callout when applicable, plus the top three vibe tags as compact
/// chips so the place narrative still has structural footing.
///
/// The full vibe-bar grid that used to live in `VibeSection` is
/// intentionally not rendered here — it overweighted the top of the
/// page and re-introduced the "stack of mini-cards" feel the redesign
/// is trying to remove. Power users can still see numbers via the
/// existing vibe_display helpers if a future detail surface needs them.
///
/// Returns SizedBox.shrink() only when there is genuinely nothing to
/// show (no summary text and no usable vibe data).
class WhyGoSection extends StatelessWidget {
  const WhyGoSection({
    super.key,
    required this.generatedSummary,
    required this.editorialSummary,
    required this.vibe,
  });

  final String? generatedSummary;
  final String? editorialSummary;
  final VibeVector? vibe;

  @override
  Widget build(BuildContext context) {
    final summary = (generatedSummary ?? editorialSummary ?? '').trim();
    final hasSummary = summary.isNotEmpty;
    final hasVibe = vibe != null && vibe!.values.isNotEmpty;

    if (!hasSummary && !hasVibe) return const SizedBox.shrink();

    final isWavy = hasVibe && vibe!.wavyScore >= 0.35;
    final isBossman = hasVibe && !isWavy && vibe!.bossmanScore >= 0.35;

    final topVibes = hasVibe ? vibe!.topTags(3) : const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHY GO',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PinitColors.aubergineSoft,
            letterSpacing: 0.12 * 11,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'The story',
          style: TextStyle(
            fontFamily: 'Rova',
            fontFamilyFallback: ['Naria'],
            fontSize: 28,
            fontWeight: FontWeight.w100,
            color: PinitColors.aubergine,
            letterSpacing: 1.3,
            height: 1.05,
          ),
        ),
        if (hasSummary) ...[
          const SizedBox(height: 14),
          Text(
            summary,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: PinitColors.aubergineSoft,
              height: 1.55,
            ),
          ),
        ],

        // Wavy / bossman energy callout — kept because it's narrative,
        // not a numeric breakdown. Folds the highest-signal piece of
        // VibeSection into the page-narrative section.
        if (isWavy) ...[
          const SizedBox(height: 16),
          const _EnergyCallout(
            emoji: '✨',
            title: 'This spot has wavy energy',
            subtitle: 'Novel, interesting, worth discovering',
            isAccent: true,
          ),
        ] else if (isBossman) ...[
          const SizedBox(height: 16),
          const _EnergyCallout(
            emoji: '🏪',
            title: 'Classic bossman joint',
            subtitle: 'Reliable, familiar, no-frills',
            isAccent: false,
          ),
        ],

        // Top vibe tag chips. Compact, no bars, no numbers — just the
        // language users actually use to describe a place.
        if (topVibes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topVibes.map((entry) {
              return _VibeTagChip(tag: entry.key);
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _EnergyCallout extends StatelessWidget {
  const _EnergyCallout({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isAccent,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    final color = isAccent ? PinitColors.accent : PinitColors.aubergine;
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
                    color: color,
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

class _VibeTagChip extends StatelessWidget {
  const _VibeTagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final icon = vibeIcons[tag] ?? Icons.label_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PinitColors.aubergine),
          const SizedBox(width: 6),
          Text(
            vibeDisplayName(tag),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PinitColors.aubergine,
            ),
          ),
        ],
      ),
    );
  }
}
