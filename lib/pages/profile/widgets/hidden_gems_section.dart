import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'pinit_colors.dart';

/// Places this user saved early, before hype
/// Shows the user's taste-making credentials
class HiddenGemsSection extends StatelessWidget {
  final List<LocationModel> savedPins;

  const HiddenGemsSection({
    Key? key,
    required this.savedPins,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: Filter for early-saved places with rising popularity
    // For now, showing first 5 pins as examples
    final gems = savedPins.take(5).toList();

    if (gems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '💎',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hidden Gems',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: PinitColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Saved early, before the hype',
                      style: TextStyle(
                        fontSize: 13,
                        color: PinitColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  // View all hidden gems
                },
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal scroll list
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: gems.length,
            itemBuilder: (context, index) {
              final location = gems[index];

              return _HiddenGemCard(
                name: location.name,
                category: location.cuisine ?? 'Restaurant',
                reason: null, // TODO: Add reason from location data
                saveCount: 12, // TODO: Get actual save count
                index: index,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HiddenGemCard extends StatelessWidget {
  final String name;
  final String category;
  final String? reason;
  final int saveCount;
  final int index;

  const _HiddenGemCard({
    required this.name,
    required this.category,
    this.reason,
    required this.saveCount,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PinitColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Early badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 12,
                    color: PinitColors.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pinned early',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.success,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Place name
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: PinitColors.textPrimary,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // Category
            Text(
              category,
              style: const TextStyle(
                fontSize: 13,
                color: PinitColors.textSecondary,
              ),
            ),

            const Spacer(),

            // Save count
            Row(
              children: [
                Icon(
                  Icons.bookmark_outline,
                  size: 14,
                  color: PinitColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '$saveCount saves',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PinitColors.textMuted,
                  ),
                ),
                if (saveCount < 50) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: PinitColors.success.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '↗ rising',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
