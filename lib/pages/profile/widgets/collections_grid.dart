import 'package:flutter/material.dart';
import 'pinit_colors.dart';

/// Playlist-style collections grid
/// Users can follow individual collections
class CollectionsGrid extends StatelessWidget {
  const CollectionsGrid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: Get actual collections from provider
    final collections = _mockCollections;

    if (collections.isEmpty) {
      return _EmptyCollections();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Collections',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Create new collection
                },
                icon: const Icon(
                  Icons.add,
                  size: 18,
                  color: PinitColors.primary,
                ),
                label: const Text(
                  'New',
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

        // Collections grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: collections.length,
            itemBuilder: (context, index) {
              final collection = collections[index];
              return _CollectionCard(
                title: collection['title'] as String,
                coverEmoji: collection['emoji'] as String,
                placesCount: collection['count'] as int,
                followersCount: collection['followers'] as int,
                gradientColors: collection['colors'] as List<Color>,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final String title;
  final String coverEmoji;
  final int placesCount;
  final int followersCount;
  final List<Color> gradientColors;

  const _CollectionCard({
    required this.title,
    required this.coverEmoji,
    required this.placesCount,
    required this.followersCount,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to collection
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: PinitColors.cardShadow,
        ),
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover emoji
                  Text(
                    coverEmoji,
                    style: const TextStyle(fontSize: 32),
                  ),

                  const Spacer(),

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Stats
                  Row(
                    children: [
                      Text(
                        '$placesCount places',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      if (followersCount > 0) ...[
                        Container(
                          width: 3,
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          '$followersCount followers',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Follow button
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Follow',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCollections extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PinitColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: PinitColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                '📚',
                style: TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No collections yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: PinitColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Organize your pins into themed collections',
            style: TextStyle(
              fontSize: 14,
              color: PinitColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              // Create collection
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: PinitColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Create your first collection',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Mock data for collections
final _mockCollections = [
  {
    'title': 'First date London',
    'emoji': '✨',
    'count': 12,
    'followers': 34,
    'colors': [const Color(0xFFE85D4C), const Color(0xFFFF7A6B)],
  },
  {
    'title': 'Late night solo eats',
    'emoji': '🌙',
    'count': 8,
    'followers': 18,
    'colors': [const Color(0xFF5B4DC7), const Color(0xFF8B7EE0)],
  },
  {
    'title': 'Parents in town',
    'emoji': '👨‍👩‍👧',
    'count': 15,
    'followers': 52,
    'colors': [const Color(0xFF34A853), const Color(0xFF5CC879)],
  },
  {
    'title': 'Coffee crawl',
    'emoji': '☕',
    'count': 9,
    'followers': 27,
    'colors': [const Color(0xFF8B5A2B), const Color(0xFFB8860B)],
  },
];
