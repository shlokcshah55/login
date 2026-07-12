import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';

enum SocialReviewInboxFilter { needsChecking, recentlySaved, all }

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
      SocialReviewInboxFilter.recentlySaved => item.recentlySaved,
      SocialReviewInboxFilter.all => true,
    };
    return inFilter && item.matchesQuery(query);
  }).toList(growable: false);
}
