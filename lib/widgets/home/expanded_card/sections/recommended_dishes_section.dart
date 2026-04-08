import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// "On the menu" — wraps recommended dishes as pill chips. Parses the
/// raw dish string (comma- or newline-separated) and caps at 6 entries.
class RecommendedDishesSection extends StatelessWidget {
  const RecommendedDishesSection({super.key, required this.recommendedDishes});

  final String? recommendedDishes;

  @override
  Widget build(BuildContext context) {
    final raw = recommendedDishes ?? '';
    if (raw.trim().isEmpty) return const SizedBox.shrink();

    // Parse: could be comma-separated or line-separated
    final dishes = raw
        .split(RegExp(r'[,\n]'))
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .take(6)
        .toList();

    if (dishes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORTH ORDERING',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PinitColors.aubergineSoft,
            letterSpacing: 0.12 * 11,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'On the menu',
          style: TextStyle(
            fontFamily: 'Rova',
            fontSize: 28,
            fontWeight: FontWeight.w100,
            color: PinitColors.aubergine,
            letterSpacing: 1.3,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: dishes.asMap().entries.map((e) {
            // First dish becomes the "must order" — accent fill, larger,
            // sparkle prefix. The rest stay outlined so the hierarchy
            // reads at a glance.
            return _DishChip(
              label: e.value,
              isFeatured: e.key == 0,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DishChip extends StatelessWidget {
  const _DishChip({required this.label, required this.isFeatured});

  final String label;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    if (isFeatured) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: PinitColors.accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PinitColors.cream,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
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
