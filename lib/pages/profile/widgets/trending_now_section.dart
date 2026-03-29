import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'location_detail_sheet.dart';
import 'pinit_colors.dart';

/// Places currently trending that this user has saved
/// Feels like "you're early, but not alone"
class TrendingNowSection extends StatelessWidget {
  final List<LocationModel> locations;

  const TrendingNowSection({
    Key? key,
    required this.locations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final trendingPins = locations;

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
            children: trendingPins.map((location) {
              return _TrendingCard(location: location);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final LocationModel location;

  const _TrendingCard({required this.location});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => LocationDetailSheet(location: location),
      ),
      child: Container(
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
                      location.name,
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
                      location.cuisine ?? 'Restaurant',
                      style: const TextStyle(
                        fontSize: 13,
                        color: PinitColors.textSecondary,
                      ),
                    ),
                    if (location.rating != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 14, color: const Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(
                            location.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PinitColors.textSecondary,
                            ),
                          ),
                          if (location.userRatingsTotal != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${location.userRatingsTotal})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: PinitColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: PinitColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
