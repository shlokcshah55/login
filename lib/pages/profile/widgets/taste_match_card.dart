import 'package:flutter/material.dart';
import 'pinit_colors.dart';

/// The "Do We Overlap?" section - instantly answers "Should I follow this person?"
class TasteMatchCard extends StatelessWidget {
  final int overlapPercentage;
  final int sharedPlaces;
  final List<String> sharedTastes;

  const TasteMatchCard({
    Key? key,
    required this.overlapPercentage,
    required this.sharedPlaces,
    required this.sharedTastes,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFFBFA),
            PinitColors.accentSoft.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: PinitColors.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: PinitColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: PinitColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 18,
                    color: PinitColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Do we overlap?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: PinitColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                // Match percentage indicator
                _MatchPercentage(percentage: overlapPercentage),
              ],
            ),

            const SizedBox(height: 20),

            // Shared signals
            _SharedSignal(
              icon: Icons.place_outlined,
              text: 'You\'ve both saved $sharedPlaces of the same places',
              highlight: sharedPlaces.toString(),
            ),

            const SizedBox(height: 12),

            ...sharedTastes.take(2).map((taste) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SharedSignal(
                    icon: Icons.restaurant_outlined,
                    text: 'Both into $taste',
                    highlight: taste,
                  ),
                )),

            const SizedBox(height: 8),

            // CTAs
            Row(
              children: [
                Expanded(
                  child: _PrimaryButton(
                    label: 'Follow to tune your feed',
                    onTap: () {
                      // Follow action
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _SecondaryButton(
                  label: 'View shared',
                  onTap: () {
                    // Navigate to shared pins
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchPercentage extends StatelessWidget {
  final int percentage;

  const _MatchPercentage({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final color = PinitColors.matchIndicator(percentage);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular indicator
          SizedBox(
            width: 20,
            height: 20,
            child: Stack(
              children: [
                CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: 3,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedSignal extends StatelessWidget {
  final IconData icon;
  final String text;
  final String highlight;

  const _SharedSignal({
    required this.icon,
    required this.text,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: PinitColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: PinitColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: PinitColors.textSecondary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: PinitColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: PinitColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: PinitColors.textPrimary.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: PinitColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
