import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/supabase/helpers/location.dart';
import 'package:login/supabase/supabase_client.dart';

/// Supabase reads/writes for the social post review flow.
///
/// Global data (social_posts, social_post_places) is written by the
/// social-free-processor; this helper reads it and records the current
/// user's review state (social_post_reviews, social_post_place_reviews).
class SocialReviewsHelper {
  final SupabaseClient _client = SupabaseClientManager().client;
  RealtimeChannel? _realtimeChannel;

  /// Fetch the user's visible review history, newest first, with the post,
  /// its place candidates, and the user's per-place actions.
  Future<List<SocialPostReviewItem>> fetchReviewItems() async {
    final user = SupabaseClientManager().currentUser;
    if (user == null) return [];

    final rows = await _client
        .from('social_post_reviews')
        .select('id, social_post_id, shared_url, status, created_at, '
            'social_posts(canonical_url, platform, creator_handle, title, '
            'caption, thumbnail_url, status, vibes, sentiment, evidence_flags, '
            'error, updated_at, processed_at, '
            'social_post_places(id, name, address, google_place_id, '
            'location_id, candidate_name, candidate_area, confidence_score, '
            'confidence_tier, extracted_context, added_by))')
        .eq('user_id', user.id)
        .inFilter(
      'status',
      ['pending', 'later', 'reviewed', 'dismissed'],
    ).order('created_at', ascending: false);

    final items = (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(SocialPostReviewItem.fromJson)
        .toList();
    if (items.isEmpty) return items;

    final placeIds =
        items.expand((item) => item.places).map((place) => place.id).toList();
    if (placeIds.isEmpty) return items;

    final actionRows = await _client
        .from('social_post_place_reviews')
        .select(
          'social_post_place_id, action, location_id, confirmed_by_user',
        )
        .eq('user_id', user.id)
        .inFilter('social_post_place_id', placeIds);

    final actions = <String, SocialPlaceAction>{};
    final savedLocationIds = <String, int>{};
    final userConfirmedPlaceIds = <String>{};
    for (final row in (actionRows as List).whereType<Map<String, dynamic>>()) {
      final action = socialPlaceActionFrom(row['action'] as String?);
      final placeId = row['social_post_place_id'] as String?;
      if (action != null && placeId != null) {
        actions[placeId] = action;
      }
      final locationId = (row['location_id'] as num?)?.toInt();
      if (placeId != null && locationId != null) {
        savedLocationIds[placeId] = locationId;
      }
      if (placeId != null && row['confirmed_by_user'] == true) {
        userConfirmedPlaceIds.add(placeId);
      }
    }

    return items
        .map((item) => item.copyWith(
              placeActions: {
                for (final place in item.places)
                  if (actions.containsKey(place.id))
                    place.id: actions[place.id]!,
              },
              savedLocationIds: {
                for (final place in item.places)
                  if (savedLocationIds.containsKey(place.id))
                    place.id: savedLocationIds[place.id]!,
              },
              userConfirmedPlaceIds: {
                for (final place in item.places)
                  if (userConfirmedPlaceIds.contains(place.id)) place.id,
              },
            ))
        .toList();
  }

  Future<void> updateReviewStatus(String reviewId, String status) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('social_post_reviews').update({
      'status': status,
      if (status == 'later') 'snoozed_at': now,
      if (status == 'reviewed' || status == 'dismissed') 'reviewed_at': now,
    }).eq('id', reviewId);
  }

  /// Record (or replace) the user's action on one place candidate.
  Future<void> upsertPlaceAction({
    required String placeId,
    required SocialPlaceAction action,
    String? correctedGooglePlaceId,
    int? correctedLocationId,
    int? savedLocationId,
    bool confirmedByUser = true,
  }) async {
    final user = SupabaseClientManager().currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _client.from('social_post_place_reviews').upsert(
      {
        'user_id': user.id,
        'social_post_place_id': placeId,
        'action': socialPlaceActionValue(action),
        'corrected_google_place_id': correctedGooglePlaceId,
        'corrected_location_id': correctedLocationId,
        'location_id': savedLocationId,
        'confirmed_by_user': confirmedByUser,
      },
      onConflict: 'user_id,social_post_place_id',
    );
  }

  /// Add a place the user picked manually to a failed / incomplete post.
  /// Returns the new social_post_places row id.
  Future<String?> insertManualPlace({
    required String postId,
    required String name,
    String? address,
    String? googlePlaceId,
    int? locationId,
  }) async {
    final user = SupabaseClientManager().currentUser;
    if (user == null) throw Exception('User not authenticated');

    final rows = await _client.from('social_post_places').insert({
      'social_post_id': postId,
      'name': name,
      'address': address,
      'google_place_id': googlePlaceId,
      'location_id': locationId,
      'added_by': user.id,
    }).select('id');
    if (rows.isNotEmpty) {
      return rows.first['id'] as String?;
    }
    return null;
  }

  /// Full LocationModel for "view place" (map focus) from a review row.
  Future<LocationModel?> fetchLocation(int locationId) async {
    final row = await _client
        .from('locations')
        .select()
        .eq('location_id', locationId)
        .maybeSingle();
    if (row == null) return null;
    final processed = await LocationHelper().processLocationsWithImages([row]);
    return processed.isEmpty ? null : processed.first;
  }

  /// Realtime updates on the user's review rows — fires when the processor
  /// creates a review or finishes processing a shared post.
  void subscribe(void Function() onChange) {
    final user = SupabaseClientManager().currentUser;
    if (user == null) return;
    unsubscribe();
    _realtimeChannel = _client
        .channel('social_post_reviews:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'social_post_reviews',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  void unsubscribe() {
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    if (channel != null) {
      _client.removeChannel(channel);
    }
  }
}
