import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'pinit_colors.dart';

/// Light activity feed - minimal, non-noisy
/// No comments. No likes. No clutter.
class RecentActivitySection extends StatelessWidget {
  final List<LocationModel> savedPins;

  const RecentActivitySection({
    Key? key,
    required this.savedPins,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: Get actual activity from provider
    final recentActivity = _generateMockActivity(savedPins);

    if (recentActivity.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: Row(
            children: [
              Text(
                'Recent',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),

        // Activity items
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: recentActivity.map((activity) {
              return _ActivityItem(
                type: activity['type'] as String,
                placeName: activity['place'] as String,
                collectionName: activity['collection'] as String?,
                timeAgo: activity['time'] as String,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _generateMockActivity(
    List<LocationModel> pins,
  ) {
    // Generate mock activity from pins
    return [
      {
        'type': 'pin',
        'place': 'Bar Lina',
        'collection': null,
        'time': '2h ago',
      },
      {
        'type': 'collection',
        'place': 'Dishoom',
        'collection': 'Late Night Eats',
        'time': '5h ago',
      },
      {
        'type': 'pin',
        'place': 'Koya',
        'collection': null,
        'time': '1d ago',
      },
      {
        'type': 'collection',
        'place': 'Quality Chop House',
        'collection': 'Date Night',
        'time': '2d ago',
      },
    ];
  }
}

class _ActivityItem extends StatelessWidget {
  final String type;
  final String placeName;
  final String? collectionName;
  final String timeAgo;

  const _ActivityItem({
    required this.type,
    required this.placeName,
    this.collectionName,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: PinitColors.surfaceLight,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: type == 'pin'
                  ? PinitColors.primary.withOpacity(0.1)
                  : PinitColors.chipLateNight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                type == 'pin' ? Icons.push_pin_outlined : Icons.folder_outlined,
                size: 18,
                color: type == 'pin'
                    ? PinitColors.primary
                    : PinitColors.textSecondary,
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Activity text
          Expanded(
            child: _buildActivityText(),
          ),

          // Time
          Text(
            timeAgo,
            style: const TextStyle(
              fontSize: 13,
              color: PinitColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityText() {
    if (type == 'pin') {
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: PinitColors.textSecondary,
            height: 1.3,
          ),
          children: [
            const TextSpan(text: 'Pinned '),
            TextSpan(
              text: placeName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: PinitColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    } else {
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: PinitColors.textSecondary,
            height: 1.3,
          ),
          children: [
            const TextSpan(text: 'Added '),
            TextSpan(
              text: placeName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: PinitColors.textPrimary,
              ),
            ),
            const TextSpan(text: ' to '),
            TextSpan(
              text: collectionName ?? 'collection',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: PinitColors.primary,
              ),
            ),
          ],
        ),
      );
    }
  }
}
