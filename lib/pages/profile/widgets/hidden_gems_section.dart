import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'location_detail_sheet.dart';
import 'pinit_colors.dart';

/// Places this user saved early, before hype
/// Shows the user's taste-making credentials
class HiddenGemsSection extends StatelessWidget {
  final List<LocationModel> locations;

  const HiddenGemsSection({
    Key? key,
    required this.locations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gems = locations;

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
              return _HiddenGemCard(location: gems[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _HiddenGemCard extends StatelessWidget {
  final LocationModel location;

  const _HiddenGemCard({required this.location});

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

              // Category
              Text(
                location.cuisine ?? 'Restaurant',
                style: const TextStyle(
                  fontSize: 13,
                  color: PinitColors.textSecondary,
                ),
              ),

              const Spacer(),

              // Rating if available, otherwise rising indicator
              if (location.rating != null)
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
                  ],
                )
              else
                Row(
                  children: [
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
