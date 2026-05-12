import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/widgets/home/expanded_card/helpers/match_result.dart';
import 'package:login/widgets/home/expanded_card/helpers/vibe_display.dart';
import 'package:login/widgets/home/expanded_card/sections/match_banner_section.dart';
import 'package:login/widgets/home/expanded_card/sections/saved_from_badge.dart';

/// Summary slab — the structural backbone introduced by the
/// 2026-04-08 restaurant expanded card redesign.
///
/// Sits directly under the hero in normal scroll flow (not sticky) and
/// replaces the previous sequence of `MatchBannerSection` +
/// `NameLocationSection` + `QuickStatsSection` + the non-persistent
/// `ActionsSection` for restaurant locations. The match data that used
/// to live in a floating overlap card is folded in here as supporting
/// copy.
///
/// The slab answers the three first-screenful questions:
///   1. What place is this?       -> name + address line
///   2. Why should I care?        -> match rationale + key facts
///   3. What can I do with it?    -> handled by the persistent dock
class SummarySlabSection extends StatelessWidget {
  const SummarySlabSection({
    super.key,
    required this.location,
    required this.match,
    required this.matchAnim,
    required this.onAddressTap,
    required this.onSavedFromTap,
    required this.isBeenTo,
    required this.isBeenToLoading,
    required this.onBeenTo,
    this.showEditBeenToRating = false,
    this.onEditBeenToRating,
    this.pinitAvgRating,
    this.pinitReviewCount = 0,
    this.creatorHandle,
  });

  final LocationModel location;
  final MatchResult match;
  final Animation<double> matchAnim;
  final VoidCallback onAddressTap;
  final VoidCallback onSavedFromTap;
  final bool isBeenTo;
  final bool isBeenToLoading;
  final VoidCallback onBeenTo;
  final bool showEditBeenToRating;
  final VoidCallback? onEditBeenToRating;
  final double? pinitAvgRating;
  final int pinitReviewCount;
  final String? creatorHandle;

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}k';
    }
    return '${(count / 1000000).toStringAsFixed(count >= 10000000 ? 0 : 1)}m';
  }

  @override
  Widget build(BuildContext context) {
    final hasMatch = match.score > 0;
    final hasVicinity = location.vicinity != null;
    final hasSourceUrl = (location.savedFrom ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Provenance — "Saved from this TikTok" flash badge sits above
        // the identity so the source is the first thing the user sees
        // when re-opening a card they pinned from a video.
        if (hasSourceUrl) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: SavedFromBadge(
              savedMethod: location.savedMethod,
              sourceUrl: location.savedFrom,
              onTap: onSavedFromTap,
              creatorHandle: creatorHandle,
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Identity — name first, big and unmistakable, with been-to badge
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                location.name,
                style: const TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 36,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  height: 1.05,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: (isBeenTo || isBeenToLoading) ? null : onBeenTo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isBeenTo ? PinitColors.accent : Colors.transparent,
                      border: Border.all(
                        color: PinitColors.accent,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: isBeenToLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor:
                                  AlwaysStoppedAnimation(PinitColors.accent),
                            ),
                          )
                        : Text(
                            isBeenTo ? "I've been" : 'Been here?',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isBeenTo
                                  ? PinitColors.cream
                                  : PinitColors.accent,
                            ),
                          ),
                  ),
                ),
                if (showEditBeenToRating) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: isBeenToLoading ? null : onEditBeenToRating,
                      child: Ink(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: PinitColors.cream,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: PinitColors.accent.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          size: 18,
                          color: PinitColors.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        if (hasVicinity) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onAddressTap,
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 16, color: PinitColors.aubergineSoft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location.vicinity!,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: PinitColors.aubergineSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_new_rounded,
                    size: 13, color: PinitColors.mute),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        // Compact key-fact cluster.
        _KeyFactsCluster(
          location: location,
          formatCount: _formatCount,
          pinitAvgRating: pinitAvgRating,
          pinitReviewCount: pinitReviewCount,
        ),

        // Match copy — supporting block, not a floating overlap card.
        // If there is no match data the slab still works with identity
        // and key facts only (per spec degraded-state requirement).
        if (hasMatch) ...[
          const SizedBox(height: 18),
          _MatchCopyBlock(match: match, matchAnim: matchAnim),
        ],
      ],
    );
  }
}

/// Compact horizontal cluster of high-signal facts. A reduced version
/// of the previous QuickStatsSection — kept inline so the slab reads as
/// one continuous block instead of a stack of mini-rows.
class _KeyFactsCluster extends StatelessWidget {
  const _KeyFactsCluster({
    required this.location,
    required this.formatCount,
    this.pinitAvgRating,
    this.pinitReviewCount = 0,
  });

  final LocationModel location;
  final String Function(int) formatCount;
  final double? pinitAvgRating;
  final int pinitReviewCount;

  bool get _showDisagree {
    if (pinitAvgRating == null || pinitReviewCount < 3) return false;
    if (location.rating == null) return false;
    return ((pinitAvgRating! / 2.0) - location.rating!).abs() >= 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final saves = location.savedCount ?? 0;
    final savesTrending = saves >= 50;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (location.rating != null)
            _FactChip(
              label: location.rating!.toStringAsFixed(1),
              icon: Icons.star_rounded,
              variant: _FactVariant.filled,
            ),
          if (_showDisagree)
            _FactChip(
              label:
                  'But our pinit users disagree · ${(pinitAvgRating! / 2.0).toStringAsFixed(1)}★',
              icon: Icons.people_rounded,
              variant: _FactVariant.orange,
            ),
          if (location.userRatingsTotal != null)
            _FactChip(
              label: '${formatCount(location.userRatingsTotal!)} reviews',
              icon: Icons.reviews_rounded,
              variant: _FactVariant.outlined,
            ),
          if (saves > 0)
            _FactChip(
              label: '${formatCount(saves)} saves',
              icon: Icons.bookmark_rounded,
              variant:
                  savesTrending ? _FactVariant.accent : _FactVariant.outlined,
            ),
          if (location.cuisinePrimary != null)
            _FactChip(
              label: location.cuisinePrimary!,
              icon: Icons.restaurant_menu_rounded,
              variant: _FactVariant.outlined,
            ),
          if (location.isOpenLate == true)
            const _FactChip(
              label: 'Late night',
              icon: Icons.nightlife_rounded,
              variant: _FactVariant.outlined,
            ),
          if (location.servesCocktails == true)
            const _FactChip(
              label: 'Cocktails',
              icon: Icons.local_bar_rounded,
              variant: _FactVariant.outlined,
            ),
          if (location.outdoorSeating == true)
            const _FactChip(
              label: 'Outdoor',
              icon: Icons.deck_rounded,
              variant: _FactVariant.outlined,
            ),
        ],
      ),
    );
  }
}

enum _FactVariant { outlined, filled, accent, orange }

class _FactChip extends StatelessWidget {
  const _FactChip({
    required this.label,
    required this.icon,
    required this.variant,
  });

  final String label;
  final IconData icon;
  final _FactVariant variant;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Border? border;
    switch (variant) {
      case _FactVariant.outlined:
        bg = PinitColors.creamSunk;
        fg = PinitColors.aubergine;
        border = Border.all(color: PinitColors.creamDeep, width: 1.5);
      case _FactVariant.filled:
        bg = PinitColors.aubergine;
        fg = PinitColors.cream;
        border = null;
      case _FactVariant.accent:
        bg = PinitColors.accent;
        fg = PinitColors.cream;
        border = null;
      case _FactVariant.orange:
        bg = const Color(0xFFFFF3CD);
        fg = const Color(0xFF92620A);
        border = Border.all(
            color: const Color(0xFFFFB800).withValues(alpha: 0.5), width: 1.5);
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Match rationale folded into the slab as supporting copy. Reuses the
/// existing [MatchRingPainter] so the animated reveal still happens —
/// just at a smaller scale and without the floating-card framing.
class _MatchCopyBlock extends StatelessWidget {
  const _MatchCopyBlock({
    required this.match,
    required this.matchAnim,
  });

  final MatchResult match;
  final Animation<double> matchAnim;

  @override
  Widget build(BuildContext context) {
    final isStrongMatch = match.score >= 0.60;
    final ringColor =
        isStrongMatch ? PinitColors.accent : PinitColors.aubergine;

    final reasonText = match.topContributors.isNotEmpty
        ? 'Based on ${match.topContributors.take(3).map((e) => vibeDisplayName(e.key).toLowerCase()).join(', ')}'
        : 'Save more places to improve matching';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: matchAnim,
          builder: (_, __) => SizedBox(
            width: 52,
            height: 52,
            child: CustomPaint(
              painter: MatchRingPainter(
                progress: matchAnim.value * match.score,
                color: ringColor,
                trackColor: PinitColors.creamDeep,
                strokeWidth: 5.0,
              ),
              child: Center(
                child: Text(
                  '${(matchAnim.value * match.percent).round()}%',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ringColor,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    match.label.toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ringColor,
                      letterSpacing: 0.12 * 11,
                    ),
                  ),
                  if (match.dietaryMatch != null) ...[
                    const SizedBox(width: 8),
                    _DietaryDot(ratio: match.dietaryMatch!),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                reasonText,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.aubergineSoft,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DietaryDot extends StatelessWidget {
  const _DietaryDot({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final ok = ratio >= 0.8;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          size: 12,
          color: ok ? PinitColors.aubergine : PinitColors.accent,
        ),
        const SizedBox(width: 4),
        Text(
          ok ? 'Diet ✓' : 'Diet ~',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ok ? PinitColors.aubergine : PinitColors.accent,
          ),
        ),
      ],
    );
  }
}
