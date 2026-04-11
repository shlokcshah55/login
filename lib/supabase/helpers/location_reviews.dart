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

  /// Submit a "been to" review via RPC (atomic: review + action insert)
  /// Rating is 1.0-10.0 with 0.1 increments. Gatekeep maps to the private column.
  Future<Map<String, dynamic>?> submitBeenTo({
    required int locationId,
    double? rating,
    String? content,
    bool gatekeep = false,
  }) async {
    try {
      final response = await _client.rpc(
        'create_location_review',
        params: {
          'p_location_id': locationId,
          if (content != null) 'p_content': content,
          if (rating != null) 'p_rating': rating,
          'p_gatekeep': gatekeep,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: submitBeenTo failed: $e');
      }
      rethrow;
    }
  }

  /// Get count of locations user has been to
  Future<int> getUserBeenToCount({
    required String userId,
  }) async {
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

  /// Get user's been_to reviews with location metadata (for swipe ranker)
  Future<List<Map<String, dynamic>>> getUserBeenToReviews({
    required String userId,
  }) async {
    try {
      final response = await _client.rpc(
        'get_user_been_to_reviews',
        params: {'p_user_id': userId},
      );
      return List<Map<String, dynamic>>.from(
        (response as List).map((row) => Map<String, dynamic>.from(row)),
      );
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: getUserBeenToReviews failed: $e');
      }
      rethrow;
    }
  }

  /// Get or create the "Been To" collection for the current user
  Future<String?> getOrCreateBeenToCollection() async {
    try {
      final userId = SupabaseClientManager().currentUser?.id;
      if (userId == null) return null;

      // Try to get existing "Been To" collection
      final existing = await _client
          .from(SupabaseConstants.tableCollections)
          .select(SupabaseConstants.columnCollectionId)
          .eq(SupabaseConstants.columnCreatedBy, userId)
          .eq(SupabaseConstants.columnName, 'Been To')
          .limit(1);

      if (existing.isNotEmpty) {
        return existing.first[SupabaseConstants.columnCollectionId] as String?;
      }

      // Create new collection if it doesn't exist
      final result = await _client.rpc(
        'create_collection',
        params: {
          'p_name': 'Been To',
          'p_is_public': true,
        },
      );
      return result as String?;
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: getOrCreateBeenToCollection failed: $e');
      }
      rethrow;
    }
  }

  /// Returns the pinit average rating (1–10 scale) and review count for a
  /// location, considering only non-private reviews. Returns null if no
  /// rated reviews exist.
  Future<({double avg, int count})?> getLocationAvgRating({
    required int locationId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLocationReviews)
          .select(SupabaseConstants.columnRatingReview)
          .eq(SupabaseConstants.columnLocationId, locationId)
          .or('${SupabaseConstants.columnPrivate}.is.null,${SupabaseConstants.columnPrivate}.eq.false');

      final ratings = (response as List)
          .map((r) => (r[SupabaseConstants.columnRatingReview] as num?)?.toDouble())
          .whereType<double>()
          .toList();

      if (ratings.isEmpty) return null;
      final avg = ratings.reduce((a, b) => a + b) / ratings.length;
      return (avg: avg, count: ratings.length);
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: getLocationAvgRating failed: $e');
      }
      return null;
    }
  }

  /// Add location to the "Been To" collection
  Future<void> addLocationToBeenToCollection({
    required String collectionId,
    required int locationId,
  }) async {
    try {
      await _client.rpc(
        'add_location_to_collection',
        params: {
          'p_collection_id': collectionId,
          'p_location_id': locationId,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: addLocationToBeenToCollection failed: $e');
      }
      rethrow;
    }
  }
}
