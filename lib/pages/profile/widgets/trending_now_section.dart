import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'pinit_colors.dart';

/// Places currently trending that this user has saved
/// Feels like "you're early, but not alone"
class TrendingNowSection extends StatelessWidget {
  final List<LocationModel> savedPins;

  const TrendingNowSection({
    Key? key,
    required this.savedPins,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: Filter for trending places (high saves this week)
    final trendingPins = savedPins.skip(2).take(4).toList();

    if (trendingPins.isEmpty) {
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
                  color: const Color(0xFFFFF0ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '🔥',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Popping Right Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: PinitColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Trending places they\'ve saved',
                      style: TextStyle(
                        fontSize: 13,
                        color: PinitColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Trending cards (vertical list)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: trendingPins.asMap().entries.map((entry) {
              final location = entry.value;

              return _TrendingCard(
                name: location.name,
                category: location.cuisine ?? 'Restaurant',
                savesThisWeek: 143, // TODO: Get actual data
                trendTag: _getTrendTag(entry.key),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String? _getTrendTag(int index) {
    final tags = [
      'London dessert wave',
      'New wine bar wave',
      null,
      'Brunch revival',
    ];
    return index < tags.length ? tags[index] : null;
  }
}

class _TrendingCard extends StatelessWidget {
  final String name;
  final String category;
  final int savesThisWeek;
  final String? trendTag;

  const _TrendingCard({
    required this.name,
    required this.category,
    required this.savesThisWeek,
    this.trendTag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PinitColors.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Place image placeholder
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: PinitColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.restaurant,
                  size: 24,
                  color: PinitColors.textMuted,
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Place info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 13,
                      color: PinitColors.textSecondary,
                    ),
                  ),
                  if (trendTag != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PinitColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        trendTag!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: PinitColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Trending indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Text(
                      '🔥',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$savesThisWeek',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: PinitColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'this week',
                  style: TextStyle(
                    fontSize: 11,
                    color: PinitColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
