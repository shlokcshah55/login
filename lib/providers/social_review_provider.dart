import 'package:flutter/foundation.dart';

import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/pages/social_review/social_review_place_item.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/services/recommendations_api.dart';
import 'package:login/supabase/helpers/location.dart';
import 'package:login/supabase/helpers/social_reviews.dart';

/// Review inbox for shared TikToks/Reels.
///
/// Holds the user's open social post reviews and performs per-place
/// save/discard/correct/manual-add actions. Saves go through the same
/// save_location_with_tags RPC as every other save, so saved places behave
/// normally across the rest of the app (Eat List, map, collections).
class SocialReviewProvider extends ChangeNotifier {
  SocialReviewProvider({
    Future<List<SocialPostReviewItem>> Function()? reviewLoader,
    Future<List<LocationModel>> Function(List<int> ids)? locationBatchLoader,
    Future<void> Function(String reviewId, String status)? reviewStatusUpdater,
  }) {
    _reviewLoader = reviewLoader ?? () => _reviews.fetchReviewItems();
    _locationBatchLoader =
        locationBatchLoader ?? (ids) => _locations.getLocationsByIds(ids);
    _reviewStatusUpdater = reviewStatusUpdater ?? _reviews.updateReviewStatus;
  }

  SocialReviewsHelper? _helper;
  LocationHelper? _locationHelper;
  final RecommendationsApi _recommendationsApi = RecommendationsApi();
  final AnalyticsService _analytics = AnalyticsService();
  late final Future<List<SocialPostReviewItem>> Function() _reviewLoader;
  late final Future<List<LocationModel>> Function(List<int> ids)
      _locationBatchLoader;
  late final Future<void> Function(String reviewId, String status)
      _reviewStatusUpdater;

  SocialReviewsHelper get _reviews => _helper ??= SocialReviewsHelper();
  LocationHelper get _locations => _locationHelper ??= LocationHelper();

  List<SocialPostReviewItem> _items = [];
  List<SocialReviewPlaceItem> _placeItems = [];
  Map<int, LocationModel> _locationsById = const {};
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  List<SocialPostReviewItem> get items => _items;
  List<SocialReviewPlaceItem> get placeItems => _placeItems;
  Map<int, LocationModel> get locationsById => _locationsById;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  /// Posts awaiting review right now (excludes "review later").
  List<SocialPostReviewItem> get pendingItems =>
      _items.where((i) => i.reviewStatus == 'pending').toList();

  List<SocialPostReviewItem> get snoozedItems =>
      _items.where((i) => i.reviewStatus == 'later').toList();

  int get pendingCount => pendingItems.length;
  int get needsCheckingCount => _items.where((item) {
        final state = item.workflowState;
        return state == SocialPostWorkflowState.needsChecking ||
            state == SocialPostWorkflowState.failed;
      }).length;

  SocialPostReviewItem? itemByPostId(String postId) {
    for (final item in _items) {
      if (item.postId == postId) return item;
    }
    return null;
  }

  void startListening() {
    _reviews.subscribe(() => refresh());
    refresh();
  }

  void stopListening() {
    _helper?.unsubscribe();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _reviewLoader();
      final projected = SocialReviewPlaceItem.fromReviews(_items);
      final locationIds = projected
          .map((item) => item.resolvedLocationId)
          .whereType<int>()
          .toSet()
          .toList(growable: false);
      final locations = locationIds.isEmpty
          ? const <LocationModel>[]
          : await _locationBatchLoader(locationIds);
      _locationsById = {
        for (final location in locations) location.locationId: location,
      };
      _placeItems = projected
          .map((item) => item.copyWith(
                location: _locationsById[item.resolvedLocationId],
              ))
          .toList(growable: false);
    } catch (e) {
      _error = 'Could not load your shared posts';
      debugPrint('[SocialReviewProvider] refresh failed: $e');
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  void trackPostShown(SocialPostReviewItem item, {required String source}) {
    _analytics.trackFeature(
      'social_post_review_shown',
      featureName: 'social_review',
      properties: <String, dynamic>{
        'social_post_id': item.postId,
        'platform': item.platform,
        'post_status': item.postStatus,
        'place_count': item.places.length,
        'source': source,
      },
    );
  }

  void trackOpenedOriginalPost(SocialPostReviewItem item) {
    _analytics.trackFeature(
      'social_post_opened_original',
      featureName: 'social_review',
      properties: <String, dynamic>{
        'social_post_id': item.postId,
        'platform': item.platform,
      },
    );
  }

  /// Swipe right: save one place to the user's Eat List. Most high/medium
  /// confidence places are already auto-saved by the time the user sees
  /// them — this mainly resolves low-confidence candidates the user
  /// confirms, or re-confirms an already-saved place (idempotent).
  Future<bool> savePlace(
    SocialPostReviewItem item,
    SocialPostPlace place,
  ) async {
    try {
      final locationId = await _resolveLocationId(item, place);
      if (locationId == null) return false;

      await _locations.saveLocation(
        locationId,
        savedMethod: item.platform,
        sourceVideoUrl: item.openUrl,
      );
      await _reviews.upsertPlaceAction(
        placeId: place.id,
        action: SocialPlaceAction.saved,
        savedLocationId: locationId,
      );
      _applyPlaceAction(item, place.id, SocialPlaceAction.saved,
          savedLocationId: locationId);
      _analytics.trackFeature(
        'social_place_saved',
        featureName: 'social_review',
        properties: <String, dynamic>{
          'social_post_id': item.postId,
          'place_id': place.id,
          'location_id': locationId,
          'confidence_tier': place.confidenceTier,
        },
        registerTap: true,
        interactionKey: 'social_place_saved',
      );
      await _finishIfFullyReviewed(item.reviewId);
      return true;
    } catch (e) {
      debugPrint('[SocialReviewProvider] savePlace failed: $e');
      return false;
    }
  }

  /// Confirm one ranked candidate. Other Google alternatives produced for
  /// the same extracted candidate are discarded, while distinct listicle
  /// venues remain independent.
  Future<bool> confirmPlace(
    SocialPostReviewItem item,
    SocialPostPlace place,
  ) async {
    if (!await savePlace(item, place)) return false;
    final candidateKey = _candidateKey(place);
    if (candidateKey.isEmpty) return true;

    for (final alternative in item.places) {
      if (alternative.id == place.id ||
          _candidateKey(alternative) != candidateKey) {
        continue;
      }
      await discardPlace(
        itemByPostId(item.postId) ?? item,
        alternative,
      );
    }
    await _finishIfFullyReviewed(item.reviewId);
    return true;
  }

  /// Confirm every candidate selected for one post. Each row is independent,
  /// even when multiple candidates share the same extracted restaurant name.
  Future<bool> confirmPlaces(
    SocialPostReviewItem item, {
    required List<SocialPostPlace> selectedPlaces,
    LocationModel? additionalPlace,
  }) async {
    if (selectedPlaces.isEmpty && additionalPlace == null) return false;

    if (additionalPlace != null &&
        !await _persistManualPlace(
          item,
          additionalPlace,
          completeReview: false,
        )) {
      return false;
    }

    final selectedIds = selectedPlaces.map((place) => place.id).toSet();
    for (final place in selectedPlaces) {
      if (!await savePlace(itemByPostId(item.postId) ?? item, place)) {
        return false;
      }
    }
    for (final place in item.places) {
      if (selectedIds.contains(place.id)) continue;
      if (!await discardPlace(itemByPostId(item.postId) ?? item, place)) {
        return false;
      }
    }

    await _completeReview(itemByPostId(item.postId) ?? item, 'reviewed');
    return true;
  }

  /// Swipe left: discard one place candidate. Most candidates are already
  /// auto-saved by the time the user reviews them, so this also removes the
  /// place from the user's Eat List if one was saved for it.
  Future<bool> discardPlace(
    SocialPostReviewItem item,
    SocialPostPlace place,
  ) async {
    try {
      final savedLocationId =
          item.savedLocationIds[place.id] ?? place.locationId;
      if (savedLocationId != null) {
        await _locations.unsaveLocation(savedLocationId);
      }
      await _reviews.upsertPlaceAction(
        placeId: place.id,
        action: SocialPlaceAction.discarded,
      );
      _applyPlaceAction(item, place.id, SocialPlaceAction.discarded);
      _analytics.trackFeature(
        'social_place_discarded',
        featureName: 'social_review',
        properties: <String, dynamic>{
          'social_post_id': item.postId,
          'place_id': place.id,
          'confidence_tier': place.confidenceTier,
        },
        registerTap: true,
        interactionKey: 'social_place_discarded',
      );
      await _finishIfFullyReviewed(item.reviewId);
      return true;
    } catch (e) {
      debugPrint('[SocialReviewProvider] discardPlace failed: $e');
      return false;
    }
  }

  /// The extraction matched the wrong venue: save the user's pick instead
  /// and record the correction as feedback (the global candidate row is
  /// left untouched). Most candidates are already auto-saved, so the
  /// original (wrong) location is unsaved first.
  Future<bool> correctPlace(
    SocialPostReviewItem item,
    SocialPostPlace place,
    LocationModel correctedPlace,
  ) async {
    try {
      // Search results carry synthetic ids — always resolve through the
      // catalog so we get a real location_id.
      final googlePlaceId = correctedPlace.googlePlaceId;
      if (googlePlaceId == null || googlePlaceId.isEmpty) return false;
      final locationId = await _recommendationsApi.addLocationByGooglePlaceId(
        googlePlaceId: googlePlaceId,
        source: item.platform,
      );
      if (locationId == null) return false;

      final previousLocationId =
          item.savedLocationIds[place.id] ?? place.locationId;
      if (previousLocationId != null && previousLocationId != locationId) {
        await _locations.unsaveLocation(previousLocationId);
      }

      await _locations.saveLocation(
        locationId,
        savedMethod: item.platform,
        sourceVideoUrl: item.openUrl,
      );
      await _reviews.upsertPlaceAction(
        placeId: place.id,
        action: SocialPlaceAction.corrected,
        correctedGooglePlaceId: googlePlaceId,
        correctedLocationId: locationId,
        savedLocationId: locationId,
      );
      _applyPlaceAction(item, place.id, SocialPlaceAction.corrected,
          savedLocationId: locationId);
      _analytics.trackFeature(
        'social_place_corrected',
        featureName: 'social_review',
        properties: <String, dynamic>{
          'social_post_id': item.postId,
          'place_id': place.id,
          'corrected_location_id': locationId,
        },
        registerTap: true,
        interactionKey: 'social_place_corrected',
      );
      await _finishIfFullyReviewed(item.reviewId);
      return true;
    } catch (e) {
      debugPrint('[SocialReviewProvider] correctPlace failed: $e');
      return false;
    }
  }

  /// Manually attach a place to a failed / empty post and save it.
  Future<bool> addManualPlace(
    SocialPostReviewItem item,
    LocationModel pickedPlace,
  ) =>
      _persistManualPlace(item, pickedPlace, completeReview: true);

  Future<bool> _persistManualPlace(
    SocialPostReviewItem item,
    LocationModel pickedPlace, {
    required bool completeReview,
  }) async {
    try {
      final googlePlaceId = pickedPlace.googlePlaceId;
      if (googlePlaceId == null || googlePlaceId.isEmpty) return false;
      final locationId = await _recommendationsApi.addLocationByGooglePlaceId(
        googlePlaceId: googlePlaceId,
        source: item.platform,
      );
      if (locationId == null) return false;

      final placeRowId = await _reviews.insertManualPlace(
        postId: item.postId,
        name: pickedPlace.name,
        address: pickedPlace.vicinity,
        googlePlaceId: googlePlaceId,
        locationId: locationId,
      );
      await _locations.saveLocation(
        locationId,
        savedMethod: item.platform,
        sourceVideoUrl: item.openUrl,
      );
      if (placeRowId != null) {
        await _reviews.upsertPlaceAction(
          placeId: placeRowId,
          action: SocialPlaceAction.manualAdded,
          savedLocationId: locationId,
        );
      }
      _analytics.trackFeature(
        'social_place_manually_added',
        featureName: 'social_review',
        properties: <String, dynamic>{
          'social_post_id': item.postId,
          'location_id': locationId,
        },
        registerTap: true,
        interactionKey: 'social_place_manually_added',
      );
      if (completeReview) {
        await _reviews.updateReviewStatus(item.reviewId, 'reviewed');
        await refresh();
      }
      return true;
    } catch (e) {
      debugPrint('[SocialReviewProvider] addManualPlace failed: $e');
      return false;
    }
  }

  /// Sticky bar: save every place the user has not acted on yet.
  Future<int> saveAll(SocialPostReviewItem item) async {
    var saved = 0;
    for (final place in item.unreviewedPlaces) {
      if (await savePlace(item, place)) saved++;
    }
    await _completeReview(item, 'reviewed');
    _analytics.trackFeature(
      'social_review_all_saved',
      featureName: 'social_review',
      properties: <String, dynamic>{
        'social_post_id': item.postId,
        'saved_count': saved,
      },
      registerTap: true,
      interactionKey: 'social_review_all_saved',
    );
    return saved;
  }

  /// Sticky bar: discard every place (including already auto-saved ones,
  /// unsaving them from the Eat List) and dismiss the post.
  Future<void> discardAll(SocialPostReviewItem item) async {
    for (final place in item.places) {
      if (item.placeActions[place.id] == SocialPlaceAction.discarded) continue;
      await discardPlace(item, place);
    }
    await _completeReview(item, 'dismissed');
    _analytics.trackFeature(
      'social_review_all_discarded',
      featureName: 'social_review',
      properties: <String, dynamic>{'social_post_id': item.postId},
      registerTap: true,
      interactionKey: 'social_review_all_discarded',
    );
  }

  /// Sticky bar: keep the post in the inbox under "Review later".
  Future<void> reviewLater(SocialPostReviewItem item) async {
    await _reviews.updateReviewStatus(item.reviewId, 'later');
    _replaceItem(item.copyWith(reviewStatus: 'later'));
    _analytics.trackFeature(
      'social_review_later',
      featureName: 'social_review',
      properties: <String, dynamic>{'social_post_id': item.postId},
      registerTap: true,
      interactionKey: 'social_review_later',
    );
  }

  /// Dismiss a failed post the user does not want to keep.
  Future<void> dismissPost(SocialPostReviewItem item) async {
    await _completeReview(item, 'dismissed');
  }

  Future<LocationModel?> fetchLocation(int locationId) =>
      _reviews.fetchLocation(locationId);

  // ── Internals ──────────────────────────────────────────────────────────────

  /// Candidates from the processor usually carry a location_id already;
  /// low-confidence ones only have a Google place id and get registered in
  /// the catalog the moment the user decides to save them.
  Future<int?> _resolveLocationId(
    SocialPostReviewItem item,
    SocialPostPlace place,
  ) async {
    if (place.locationId != null) return place.locationId;
    final googlePlaceId = place.googlePlaceId;
    if (googlePlaceId == null || googlePlaceId.isEmpty) return null;
    return _recommendationsApi.addLocationByGooglePlaceId(
      googlePlaceId: googlePlaceId,
      source: item.platform,
    );
  }

  void _applyPlaceAction(
    SocialPostReviewItem item,
    String placeId,
    SocialPlaceAction action, {
    int? savedLocationId,
    bool confirmedByUser = true,
  }) {
    final current = itemByPostId(item.postId) ?? item;
    final updatedActions =
        Map<String, SocialPlaceAction>.from(current.placeActions)
          ..[placeId] = action;
    final updatedSavedIds = Map<String, int>.from(current.savedLocationIds);
    if (savedLocationId != null) {
      updatedSavedIds[placeId] = savedLocationId;
    } else {
      updatedSavedIds.remove(placeId);
    }
    final updatedConfirmations = Set<String>.from(
      current.userConfirmedPlaceIds,
    );
    if (confirmedByUser) updatedConfirmations.add(placeId);
    _replaceItem(current.copyWith(
      placeActions: updatedActions,
      savedLocationIds: updatedSavedIds,
      userConfirmedPlaceIds: updatedConfirmations,
    ));
  }

  /// Once every candidate has an action, the review resolves itself.
  Future<void> _finishIfFullyReviewed(String reviewId) async {
    final item = _items.where((i) => i.reviewId == reviewId).firstOrNull;
    if (item == null ||
        !item.hasPlaces ||
        item.pendingReviewPlaces.isNotEmpty) {
      return;
    }
    await _completeReview(item, 'reviewed');
  }

  Future<void> _completeReview(
    SocialPostReviewItem item,
    String status,
  ) async {
    try {
      await _reviewStatusUpdater(item.reviewId, status);
    } catch (e) {
      debugPrint('[SocialReviewProvider] updateReviewStatus failed: $e');
    }
    final current = itemByPostId(item.postId) ?? item;
    _replaceItem(current.copyWith(reviewStatus: status));
  }

  void _replaceItem(SocialPostReviewItem updated) {
    _items = _items
        .map((i) => i.reviewId == updated.reviewId ? updated : i)
        .toList();
    _rebuildPlaceItems();
    notifyListeners();
  }

  void _rebuildPlaceItems() {
    _placeItems = SocialReviewPlaceItem.fromReviews(_items)
        .map((item) => item.copyWith(
              location: _locationsById[item.resolvedLocationId],
            ))
        .toList(growable: false);
  }

  String _candidateKey(SocialPostPlace place) {
    return (place.candidateName ?? place.name)
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
