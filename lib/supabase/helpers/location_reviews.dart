import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../supabase_client.dart';

class LocationReviewsHelper {
  final SupabaseClient _client = SupabaseClientManager().client;

  Future<Map<String, dynamic>?> getUserReview({
    required int locationId,
    required String userId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLocationReviews)
          .select()
          .eq(SupabaseConstants.columnLocationId, locationId)
          .eq(SupabaseConstants.columnUserId, userId)
          .order(SupabaseConstants.columnCreatedAt, ascending: false)
          .limit(1);
      if (response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: Failed to fetch user review: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getLatestPublicReview({
    required int locationId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLocationReviews)
          .select()
          .eq(SupabaseConstants.columnLocationId, locationId)
          .or('${SupabaseConstants.columnPrivate}.is.null,${SupabaseConstants.columnPrivate}.eq.false')
          .order(SupabaseConstants.columnCreatedAt, ascending: false)
          .limit(1);
      if (response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: Failed to fetch public review: $e');
      }
      rethrow;
    }
  }

  /// Atomically inserts a review row + fires the `been_to` action via the
  /// `create_location_review` RPC. Used by the "Been to" flow in the
  /// expanded location card.
  Future<Map<String, dynamic>?> submitBeenTo({
    required int locationId,
    double? rating,
    String? content,
    bool gatekeep = false,
  }) async {
    try {
      final response = await _client.rpc('create_location_review', params: {
        'p_location_id': locationId,
        if (content != null) 'p_content': content,
        if (rating != null) 'p_rating': rating,
        'p_gatekeep': gatekeep,
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: submitBeenTo failed: $e');
      }
      rethrow;
    }
  }

  /// Returns the number of locations the user has marked as `been_to`.
  /// Used to gate the swipe-ranker UI (>5 reviews → ranker; otherwise the
  /// plain rating sheet).
  Future<int> getUserBeenToCount({required String userId}) async {
    try {
      final response = await _client.rpc(
        'get_user_been_to_count',
        params: {'p_user_id': userId},
      );
      return (response as int?) ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: getUserBeenToCount failed: $e');
      }
      rethrow;
    }
  }

  /// Returns all of the user's been-to reviews joined with the location's
  /// name + image. Used by the swipe ranker for binary comparisons.
  Future<List<Map<String, dynamic>>> getUserBeenToReviews({
    required String userId,
  }) async {
    try {
      final response = await _client.rpc(
        'get_user_been_to_reviews',
        params: {'p_user_id': userId},
      );
      return List<Map<String, dynamic>>.from(
        (response as List).map((r) => Map<String, dynamic>.from(r)),
      );
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: getUserBeenToReviews failed: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> createReview({
    required int locationId,
    required String userId,
    required String content,
    required int rating,
    bool isPrivate = false,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLocationReviews)
          .insert({
            SupabaseConstants.columnLocationId: locationId,
            SupabaseConstants.columnUserId: userId,
            SupabaseConstants.columnContentReview: content,
            SupabaseConstants.columnRatingReview: rating,
            SupabaseConstants.columnPrivate: isPrivate,
          })
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: Failed to create review: $e');
      }
      rethrow;
    }
  }
}
