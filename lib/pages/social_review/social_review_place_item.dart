import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';

enum SocialReviewInboxFilter {
  needsChecking,
  processing,
  recentlySaved,
  all,
}

/// One shared post in the inbox, enriched with any catalog locations resolved
/// from its ranked candidates.
class SocialReviewPostItem {
  const SocialReviewPostItem({
    required this.review,
    this.locationsById = const {},
  });

  final SocialPostReviewItem review;
  final Map<int, LocationModel> locationsById;

  String get id => review.reviewId;
  SocialPostWorkflowState get state => review.workflowState;

  SocialPostPlace? get bestCandidate {
    if (review.places.isEmpty) return null;
    return review.places.reduce((best, next) {
      return (next.confidenceScore ?? 0) > (best.confidenceScore ?? 0)
          ? next
          : best;
    });
  }

  List<LocationModel> get locations {
    final seen = <int>{};
    final resolved = <LocationModel>[];
    for (final place in review.places) {
      final id = review.savedLocationIds[place.id] ?? place.locationId;
      if (id == null || !seen.add(id)) continue;
      final location = locationsById[id];
      if (location != null) resolved.add(location);
    }
    return resolved;
  }

  String get summary {
    for (final value in [review.caption, review.title]) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) return normalized;
    }
    final candidate = bestCandidate;
    if (candidate != null) {
      final area = candidate.candidateArea?.trim();
      return area == null || area.isEmpty
          ? candidate.name
          : '${candidate.name} · $area';
    }
    return 'Shared post';
  }

  String get statusLabel {
    return switch (state) {
      SocialPostWorkflowState.processing => 'Still processing',
      SocialPostWorkflowState.needsChecking => 'Needs checking',
      SocialPostWorkflowState.failed => 'Failed',
      SocialPostWorkflowState.resolved => 'Resolved',
      SocialPostWorkflowState.dismissed => 'Dismissed',
    };
  }

  String get statusExplanation {
    return switch (state) {
      SocialPostWorkflowState.processing =>
        'Pinit is analysing the post for restaurant details.',
      SocialPostWorkflowState.needsChecking => bestCandidate == null
          ? 'We found some context, but could not confidently match a restaurant.'
          : 'We found a possible match. Check it before saving.',
      SocialPostWorkflowState.failed => review.isProcessing
          ? 'Analysis did not finish. You can still add the restaurant.'
          : 'Pinit could not finish extracting a reliable restaurant.',
      SocialPostWorkflowState.resolved =>
        'The restaurant details from this post have been saved.',
      SocialPostWorkflowState.dismissed => 'You chose not to save this post.',
    };
  }

  String? get primaryActionLabel {
    return switch (state) {
      SocialPostWorkflowState.processing => null,
      SocialPostWorkflowState.needsChecking =>
        bestCandidate == null ? 'Find restaurant' : 'Review match',
      SocialPostWorkflowState.failed => 'Find restaurant',
      SocialPostWorkflowState.resolved => 'View saved',
      SocialPostWorkflowState.dismissed => null,
    };
  }

  List<String> get insightChips {
    final chips = <String>[];

    void add(String? value) {
      final normalized = value?.trim();
      if (normalized == null ||
          normalized.isEmpty ||
          chips.any((chip) => chip.toLowerCase() == normalized.toLowerCase())) {
        return;
      }
      chips.add(normalized);
    }

    for (final location in locations) {
      add(location.displayCuisine);
    }
    for (final place in review.places) {
      for (final dish in place.keyDishNames) {
        add(dish);
      }
      for (final vibe in place.vibeSignalNames) {
        add(vibe);
      }
    }
    for (final location in locations) {
      final level = location.priceLevel;
      if (level != null && level > 0) add('£' * level.clamp(1, 4));
    }
    add(bestCandidate?.candidateArea);
    for (final vibe in review.topVibes) {
      add(vibe);
    }
    return chips.take(3).toList(growable: false);
  }

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final searchable = <String?>[
      review.platformLabel,
      review.creatorHandle,
      review.title,
      review.caption,
      ...review.topVibes,
      for (final place in review.places) ...[
        place.name,
        place.address,
        place.candidateName,
        place.candidateArea,
        place.creatorNotes,
        ...place.keyDishNames,
      ],
      for (final location in locations) ...[
        location.name,
        location.displayCuisine,
        location.vicinity,
      ],
    ].whereType<String>().join(' ').toLowerCase();
    return searchable.contains(normalized);
  }
}

List<SocialReviewPostItem> visibleSocialReviewPosts(
  Iterable<SocialReviewPostItem> items, {
  required SocialReviewInboxFilter filter,
  required String query,
}) {
  return items.where((item) {
    final inFilter = switch (filter) {
      SocialReviewInboxFilter.needsChecking =>
        item.state == SocialPostWorkflowState.needsChecking ||
            item.state == SocialPostWorkflowState.failed,
      SocialReviewInboxFilter.processing =>
        item.state == SocialPostWorkflowState.processing,
      SocialReviewInboxFilter.recentlySaved =>
        item.state == SocialPostWorkflowState.resolved,
      SocialReviewInboxFilter.all => true,
    };
    return inFilter && item.matchesQuery(query);
  }).toList(growable: false);
}

/// One restaurant-shaped row in the social review inbox.
///
/// A post can produce multiple rows. Failed posts without a candidate produce
/// one fallback row so the user still has somewhere to recover the share.
class SocialReviewPlaceItem {
  const SocialReviewPlaceItem({
    required this.review,
    this.place,
    this.location,
  });

  final SocialPostReviewItem review;
  final SocialPostPlace? place;
  final LocationModel? location;

  String get id => place?.id ?? 'review:${review.reviewId}';

  SocialPlaceAction? get action {
    final placeId = place?.id;
    return placeId == null ? null : review.placeActions[placeId];
  }

  int? get resolvedLocationId {
    final currentPlace = place;
    if (currentPlace == null) return null;
    return review.savedLocationIds[currentPlace.id] ?? currentPlace.locationId;
  }

  bool get isProcessing => review.isProcessing;

  bool get recentlySaved {
    switch (action) {
      case SocialPlaceAction.saved:
      case SocialPlaceAction.corrected:
      case SocialPlaceAction.manualAdded:
        return true;
      case SocialPlaceAction.discarded:
      case null:
        return false;
    }
  }

  bool get needsChecking {
    if (isProcessing || recentlySaved) return false;
    if (review.isFailed || place == null) return true;
    return place!.isLowConfidence || resolvedLocationId == null;
  }

  String get statusLabel {
    if (isProcessing) return 'Processing';
    if (recentlySaved) return 'Saved';
    if (place == null || review.isFailed) return 'Find restaurant';
    return 'Check match';
  }

  String get displayName {
    final locationName = location?.name.trim();
    if (locationName != null && locationName.isNotEmpty) return locationName;
    final placeName = place?.name.trim();
    if (placeName != null && placeName.isNotEmpty) return placeName;
    final candidateName = place?.candidateName?.trim();
    if (candidateName != null && candidateName.isNotEmpty) {
      return candidateName;
    }
    return 'Restaurant not identified';
  }

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final searchable = <String?>[
      displayName,
      location?.displayCuisine,
      location?.vicinity,
      place?.address,
      place?.candidateName,
      place?.candidateArea,
      review.creatorHandle,
      review.title,
      ...?place?.keyDishNames,
    ].whereType<String>().join(' ').toLowerCase();

    return searchable.contains(normalized);
  }

  SocialReviewPlaceItem copyWith({LocationModel? location}) {
    return SocialReviewPlaceItem(
      review: review,
      place: place,
      location: location ?? this.location,
    );
  }

  static List<SocialReviewPlaceItem> fromReviews(
    Iterable<SocialPostReviewItem> reviews,
  ) {
    return [
      for (final review in reviews)
        if (review.places.isEmpty)
          SocialReviewPlaceItem(review: review)
        else
          for (final place in review.places)
            SocialReviewPlaceItem(review: review, place: place),
    ];
  }
}

List<SocialReviewPlaceItem> visibleSocialReviewPlaces(
  Iterable<SocialReviewPlaceItem> items, {
  required SocialReviewInboxFilter filter,
  required String query,
}) {
  return items.where((item) {
    final inFilter = switch (filter) {
      SocialReviewInboxFilter.needsChecking => item.needsChecking,
      SocialReviewInboxFilter.processing => item.isProcessing,
      SocialReviewInboxFilter.recentlySaved => item.recentlySaved,
      SocialReviewInboxFilter.all => true,
    };
    return inFilter && item.matchesQuery(query);
  }).toList(growable: false);
}
