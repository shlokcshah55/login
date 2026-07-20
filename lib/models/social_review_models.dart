import 'package:login/utils/social_video_link.dart';

/// Per-user action recorded against one place candidate on a social post.
enum SocialPlaceAction { saved, discarded, corrected, manualAdded }

SocialPlaceAction? socialPlaceActionFrom(String? value) {
  switch (value) {
    case 'saved':
      return SocialPlaceAction.saved;
    case 'discarded':
      return SocialPlaceAction.discarded;
    case 'corrected':
      return SocialPlaceAction.corrected;
    case 'manual_added':
      return SocialPlaceAction.manualAdded;
  }
  return null;
}

String socialPlaceActionValue(SocialPlaceAction action) {
  switch (action) {
    case SocialPlaceAction.saved:
      return 'saved';
    case SocialPlaceAction.discarded:
      return 'discarded';
    case SocialPlaceAction.corrected:
      return 'corrected';
    case SocialPlaceAction.manualAdded:
      return 'manual_added';
  }
}

enum SocialPostWorkflowState {
  processing,
  needsChecking,
  failed,
  resolved,
  dismissed,
}

/// One place candidate extracted from (or manually added to) a social post.
class SocialPostPlace {
  final String id;
  final String name;
  final String? address;
  final String? googlePlaceId;
  final int? locationId;
  final String? candidateName;
  final String? candidateArea;
  final double? confidenceScore;
  final String? confidenceTier; // high | medium | low
  final Map<String, dynamic> extractedContext;
  final String? addedBy;

  const SocialPostPlace({
    required this.id,
    required this.name,
    this.address,
    this.googlePlaceId,
    this.locationId,
    this.candidateName,
    this.candidateArea,
    this.confidenceScore,
    this.confidenceTier,
    this.extractedContext = const {},
    this.addedBy,
  });

  factory SocialPostPlace.fromJson(Map<String, dynamic> json) {
    return SocialPostPlace(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Unknown place',
      address: json['address'] as String?,
      googlePlaceId: json['google_place_id'] as String?,
      locationId: (json['location_id'] as num?)?.toInt(),
      candidateName: json['candidate_name'] as String?,
      candidateArea: json['candidate_area'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      confidenceTier: json['confidence_tier'] as String?,
      extractedContext:
          (json['extracted_context'] as Map<String, dynamic>?) ?? const {},
      addedBy: json['added_by'] as String?,
    );
  }

  bool get isLowConfidence => confidenceTier == 'low';

  List<String> get keyDishNames {
    final dishes = extractedContext['key_dishes'];
    if (dishes is! List) return const [];
    return dishes
        .whereType<Map<String, dynamic>>()
        .map((d) => d['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  String? get creatorNotes {
    final notes = extractedContext['creator_notes']?.toString().trim();
    return (notes == null || notes.isEmpty) ? null : notes;
  }
}

/// One social post the user shared, together with their review state.
class SocialPostReviewItem {
  final String reviewId;
  final String postId;
  final String sharedUrl;
  final String reviewStatus; // pending | later | reviewed | dismissed
  final String canonicalUrl;
  final String platform; // tiktok | instagram
  final String? creatorHandle;
  final String? title;
  final String? caption;
  final String? thumbnailUrl;
  final String postStatus; // processing | processed | failed
  final Map<String, dynamic> vibes;
  final String? sentiment;
  final Map<String, dynamic> evidenceFlags;
  final String? processingError;
  final DateTime? postUpdatedAt;
  final DateTime? processedAt;
  final DateTime sharedAt;
  final List<SocialPostPlace> places;

  /// This user's per-place actions, keyed by social_post_place_id.
  final Map<String, SocialPlaceAction> placeActions;

  /// The location actually saved to this user's Eat List for a place,
  /// keyed by social_post_place_id — set for auto-saved, manually saved, or
  /// corrected candidates. May differ from [SocialPostPlace.locationId]
  /// once a place has been corrected to a different venue.
  final Map<String, int> savedLocationIds;

  /// Candidate ids for which the user explicitly made a decision. Processor
  /// auto-saves remain false so medium-confidence matches still need review.
  final Set<String> userConfirmedPlaceIds;

  const SocialPostReviewItem({
    required this.reviewId,
    required this.postId,
    required this.sharedUrl,
    required this.reviewStatus,
    required this.canonicalUrl,
    required this.platform,
    this.creatorHandle,
    this.title,
    this.caption,
    this.thumbnailUrl,
    required this.postStatus,
    this.vibes = const {},
    this.sentiment,
    this.evidenceFlags = const {},
    this.processingError,
    this.postUpdatedAt,
    this.processedAt,
    required this.sharedAt,
    this.places = const [],
    this.placeActions = const {},
    this.savedLocationIds = const {},
    this.userConfirmedPlaceIds = const {},
  });

  factory SocialPostReviewItem.fromJson(Map<String, dynamic> json) {
    final post = (json['social_posts'] as Map<String, dynamic>?) ?? const {};
    final placesJson = post['social_post_places'];
    final places = placesJson is List
        ? placesJson
            .whereType<Map<String, dynamic>>()
            .map(SocialPostPlace.fromJson)
            .toList()
        : <SocialPostPlace>[];
    // Highest-confidence candidates first; manual additions last.
    places.sort(
        (a, b) => (b.confidenceScore ?? 0).compareTo(a.confidenceScore ?? 0));

    return SocialPostReviewItem(
      reviewId: json['id'] as String,
      postId: json['social_post_id'] as String,
      sharedUrl: (json['shared_url'] as String?) ?? '',
      reviewStatus: (json['status'] as String?) ?? 'pending',
      canonicalUrl: (post['canonical_url'] as String?) ?? '',
      platform: (post['platform'] as String?) ?? 'tiktok',
      creatorHandle: post['creator_handle'] as String?,
      title: post['title'] as String?,
      caption: post['caption'] as String?,
      thumbnailUrl: post['thumbnail_url'] as String?,
      postStatus: (post['status'] as String?) ?? 'processing',
      vibes: (post['vibes'] as Map<String, dynamic>?) ?? const {},
      sentiment: post['sentiment'] as String?,
      evidenceFlags:
          (post['evidence_flags'] as Map<String, dynamic>?) ?? const {},
      processingError: post['error'] as String?,
      postUpdatedAt: DateTime.tryParse(post['updated_at']?.toString() ?? ''),
      processedAt: DateTime.tryParse(post['processed_at']?.toString() ?? ''),
      sharedAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      places: places,
    );
  }

  SocialPostReviewItem copyWith({
    String? reviewStatus,
    Map<String, SocialPlaceAction>? placeActions,
    Map<String, int>? savedLocationIds,
    Set<String>? userConfirmedPlaceIds,
    List<SocialPostPlace>? places,
  }) {
    return SocialPostReviewItem(
      reviewId: reviewId,
      postId: postId,
      sharedUrl: sharedUrl,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      canonicalUrl: canonicalUrl,
      platform: platform,
      creatorHandle: creatorHandle,
      title: title,
      caption: caption,
      thumbnailUrl: thumbnailUrl,
      postStatus: postStatus,
      vibes: vibes,
      sentiment: sentiment,
      evidenceFlags: evidenceFlags,
      processingError: processingError,
      postUpdatedAt: postUpdatedAt,
      processedAt: processedAt,
      sharedAt: sharedAt,
      places: places ?? this.places,
      placeActions: placeActions ?? this.placeActions,
      savedLocationIds: savedLocationIds ?? this.savedLocationIds,
      userConfirmedPlaceIds:
          userConfirmedPlaceIds ?? this.userConfirmedPlaceIds,
    );
  }

  bool get isProcessing => postStatus == 'processing';
  bool get isFailed => postStatus == 'failed';
  bool get hasPlaces => places.isNotEmpty;

  SocialPostWorkflowState get workflowState =>
      workflowStateAt(DateTime.now().toUtc());

  SocialPostWorkflowState workflowStateAt(DateTime now) {
    if (reviewStatus == 'dismissed') {
      return SocialPostWorkflowState.dismissed;
    }
    if (postStatus == 'processing') {
      final lastUpdate = postUpdatedAt ?? sharedAt;
      if (now.toUtc().difference(lastUpdate.toUtc()) >
          const Duration(minutes: 30)) {
        return SocialPostWorkflowState.failed;
      }
      return SocialPostWorkflowState.processing;
    }
    if (postStatus == 'failed') return SocialPostWorkflowState.failed;
    if (reviewStatus == 'reviewed') return SocialPostWorkflowState.resolved;
    if (hasPlaces && pendingReviewPlaces.isEmpty) {
      return SocialPostWorkflowState.resolved;
    }
    return SocialPostWorkflowState.needsChecking;
  }

  /// The best URL to open the original post with.
  String get openUrl => canonicalUrl.isNotEmpty ? canonicalUrl : sharedUrl;

  SocialVideoPlatform get platformType =>
      socialVideoPlatformFrom(platform: platform, sourceUrl: openUrl) ??
      SocialVideoPlatform.tiktok;

  String get platformLabel =>
      platformType == SocialVideoPlatform.instagram ? 'Reel' : 'TikTok';

  /// Places the user has not acted on yet.
  List<SocialPostPlace> get unreviewedPlaces =>
      places.where((p) => !placeActions.containsKey(p.id)).toList();

  List<SocialPostPlace> get pendingReviewPlaces {
    return places.where((place) {
      if (userConfirmedPlaceIds.contains(place.id)) return false;
      final action = placeActions[place.id];
      if (action == SocialPlaceAction.corrected ||
          action == SocialPlaceAction.manualAdded ||
          action == SocialPlaceAction.discarded) {
        return false;
      }
      final resolvedLocationId = savedLocationIds[place.id] ?? place.locationId;
      final confidentlyAutoSaved = place.confidenceTier == 'high' &&
          action == SocialPlaceAction.saved &&
          resolvedLocationId != null;
      return !confidentlyAutoSaved;
    }).toList(growable: false);
  }

  /// Top post-level vibes, strongest first, for the chips row.
  List<String> get topVibes {
    final entries = vibes.entries.where((e) => e.value is num).toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    return entries.take(4).map((e) => e.key.replaceAll('_', ' ')).toList();
  }
}
