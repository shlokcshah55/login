import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// Horizontally scrollable row of pill chips summarising key location facts
/// (rating, review count, save count, cuisine, late night, cocktails…).
class QuickStatsSection extends StatelessWidget {
  const QuickStatsSection({super.key, required this.location});

  final LocationModel location;

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}k';
    }
    return '${(count / 1000000).toStringAsFixed(count >= 10000000 ? 0 : 1)}m';
  }

  @override
  Widget build(BuildContext context) {
    final saves = location.savedCount ?? 0;
    // 50+ saves gets a "trending" treatment so social proof reads at a
    // glance instead of being lost in a row of identical chips.
    final savesTrending = saves >= 50;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Rating is the visual anchor — filled aubergine.
          if (location.rating != null)
            _StatChip(
              label: location.rating!.toStringAsFixed(1),
              icon: Icons.star_rounded,
              variant: _StatVariant.filled,
            ),
          if (location.userRatingsTotal != null)
            _StatChip(
              label: '${_formatCount(location.userRatingsTotal!)} reviews',
              icon: Icons.reviews_rounded,
              variant: _StatVariant.outlined,
            ),
          if (saves > 0)
            _StatChip(
              label: '${_formatCount(saves)} saves',
              icon: Icons.bookmark_rounded,
              variant: savesTrending
                  ? _StatVariant.accent
                  : _StatVariant.outlined,
            ),
          if (location.cuisinePrimary != null)
            _StatChip(
              label: location.cuisinePrimary!,
              icon: Icons.restaurant_menu_rounded,
              variant: _StatVariant.outlined,
            ),
          if (location.isOpenLate == true)
            const _StatChip(
              label: 'Late night',
              icon: Icons.nightlife_rounded,
              variant: _StatVariant.outlined,
            ),
          if (location.servesCocktails == true)
            const _StatChip(
              label: 'Cocktails',
              icon: Icons.local_bar_rounded,
              variant: _StatVariant.outlined,
            ),
          if (location.outdoorSeating == true)
            const _StatChip(
              label: 'Outdoor',
              icon: Icons.deck_rounded,
              variant: _StatVariant.outlined,
            ),
        ],
      ),
    );
  }
}

enum _StatVariant {
  /// Default — cream-sunk fill, aubergine border + text.
  outlined,

  /// Aubergine fill, cream icon + text. Used for the rating anchor.
  filled,

  /// Accent (#ec3d2c) fill, cream text. Reserved for the "trending"
  /// saves chip so it doesn't disappear into the row.
  accent,
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.icon,
    required this.variant,
  });

  final String label;
  final IconData icon;
  final _StatVariant variant;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Border? border;
    switch (variant) {
      case _StatVariant.outlined:
        bg = PinitColors.creamSunk;
        fg = PinitColors.aubergine;
        border = Border.all(color: PinitColors.creamDeep, width: 1.5);
      case _StatVariant.filled:
        bg = PinitColors.aubergine;
        fg = PinitColors.cream;
        border = null;
      case _StatVariant.accent:
        bg = PinitColors.accent;
        fg = PinitColors.cream;
        border = null;
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
