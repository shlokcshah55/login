import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_card/helpers/similar_place.dart';
import 'package:login/widgets/home/expanded_card/sections/review_section.dart';
import 'package:login/widgets/home/expanded_card/sections/similar_places_section.dart';

/// "Social proof" — third editorial body zone in the redesigned
/// restaurant expanded card. Groups reviews and similar-place
/// recommendations adjacently so social validation and recommendation
/// depth live in the same part of the scroll instead of being
/// scattered across the long body.
///
/// This is intentionally a thin layout grouping — the existing
/// [ReviewSection] and [SimilarPlacesSection] widgets are reused
/// verbatim, each keeping its own editorial header. The structural win
/// is adjacency, not a new wrapping header that would just stack on top
/// of the existing ones and re-create the "mini-card stack" feel the
/// redesign is removing.
class SocialProofSection extends StatelessWidget {
  const SocialProofSection({
    super.key,
    required this.location,
    required this.similarPlaces,
    required this.onSimilarPlaceTap,
    this.pinitReviews = const [],
    this.friendIds = const {},
  });

  final LocationModel location;
  final List<SimilarPlace> similarPlaces;
  final ValueChanged<SimilarPlace> onSimilarPlaceTap;
  final List<Map<String, dynamic>> pinitReviews;
  final Set<String> friendIds;

  @override
  Widget build(BuildContext context) {
    final hasSimilar = similarPlaces.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReviewSection(
          location: location,
          pinitReviews: pinitReviews,
          friendIds: friendIds,
        ),
        if (hasSimilar) ...[
          const SizedBox(height: 32),
          SimilarPlacesSection(
            similarPlaces: similarPlaces,
            onPlaceTap: onSimilarPlaceTap,
          ),
        ],
      ],
    );
  }
}
