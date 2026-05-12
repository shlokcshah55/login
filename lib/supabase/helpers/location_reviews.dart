import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:login/services/been_to_rankings_events.dart';
import '../constants.dart';
import '../supabase_client.dart';

class LocationReviewsHelper {
  final SupabaseClient _client = SupabaseClientManager().client;

  Future<Set<int>> getUserBeenToLocationIds({
    required String userId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLocationReviews)
          .select(SupabaseConstants.columnLocationId)
          .eq(SupabaseConstants.columnUserId, userId);

      return (response as List)
          .map((row) => row[SupabaseConstants.columnLocationId])
          .whereType<num>()
          .map((id) => id.toInt())
          .toSet();
    } catch (e) {
      if (kDebugMode) {
        print(
          'LocationReviewsHelper: getUserBeenToLocationIds failed: $e',
        );
      }
      rethrow;
    }
  }

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

  /// Mark a location as "been to" without creating a review row.
  /// Calls create_user_location_action with action='been_to' (idempotent).
  Future<void> markBeenTo({required int locationId}) async {
    final user = SupabaseClientManager().currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    await _client.rpc('create_user_location_action', params: {
      'p_user_id': user.id,
      'p_location_id': locationId,
      'p_action': 'been_to',
    });
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
      final userId = SupabaseClientManager().currentUser?.id;
      if (userId != null) {
        BeenToRankingsEvents.instance.notifyChanged(userId);
      }
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: submitBeenTo failed: $e');
      }
      rethrow;
    }
  }

  /// Update an existing "been to" review without inserting a new row.
  /// Intended for editing a previously submitted rating/notes.
  ///
  /// Rating is 1.0-10.0 with 0.1 increments. Gatekeep maps to the private column.
  Future<Map<String, dynamic>?> updateBeenTo({
    required int locationId,
    required double rating,
    String? content,
    bool gatekeep = false,
  }) async {
    try {
      final response = await _client.rpc(
        'update_location_review',
        params: {
          'p_location_id': locationId,
          'p_rating': rating,
          'p_content': content,
          'p_gatekeep': gatekeep,
        },
      );
      final userId = SupabaseClientManager().currentUser?.id;
      if (userId != null) {
        BeenToRankingsEvents.instance.notifyChanged(userId);
      }
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: updateBeenTo failed: $e');
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
          .map((r) =>
              (r[SupabaseConstants.columnRatingReview] as num?)?.toDouble())
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

  /// Fetch all non-private reviews for a location, joined with the reviewer's
  /// public profile (name, username, profile_image_url).
  Future<List<Map<String, dynamic>>> getPublicReviewsWithProfiles({
    required int locationId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLocationReviews)
          .select(
            '${SupabaseConstants.columnRatingReview},'
            '${SupabaseConstants.columnContentReview},'
            '${SupabaseConstants.columnCreatedAt},'
            '${SupabaseConstants.columnUserId},'
            '${SupabaseConstants.tableUsers}(${SupabaseConstants.name},${SupabaseConstants.columnUsername},${SupabaseConstants.columnProfileImageUrl})',
          )
          .eq(SupabaseConstants.columnLocationId, locationId)
          .or('${SupabaseConstants.columnPrivate}.is.null,${SupabaseConstants.columnPrivate}.eq.false')
          .order(SupabaseConstants.columnCreatedAt, ascending: false);

      return List<Map<String, dynamic>>.from(
        (response as List).map((r) => Map<String, dynamic>.from(r)),
      );
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: getPublicReviewsWithProfiles failed: $e');
      }
      return [];
    }
  }

  /// Returns the set of mutual friend user IDs for the current user.
  /// Uses two lightweight queries (no per-friend profile fetch).
  Future<Set<String>> getFriendIds() async {
    try {
      final user = SupabaseClientManager().currentUser;
      if (user == null) return {};

      final following = await _client
          .from(SupabaseConstants.tableUserFriends)
          .select(SupabaseConstants.columnFolloweeId)
          .eq(SupabaseConstants.columnFollowerId, user.id)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      final followers = await _client
          .from(SupabaseConstants.tableUserFriends)
          .select(SupabaseConstants.columnFollowerId)
          .eq(SupabaseConstants.columnFolloweeId, user.id)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      final followingIds = (following as List)
          .map((r) => r[SupabaseConstants.columnFolloweeId] as String)
          .toSet();
      final followerIds = (followers as List)
          .map((r) => r[SupabaseConstants.columnFollowerId] as String)
          .toSet();

      return followingIds.intersection(followerIds);
    } catch (e) {
      if (kDebugMode) {
        print('LocationReviewsHelper: getFriendIds failed: $e');
      }
      return {};
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
        print(
            'LocationReviewsHelper: addLocationToBeenToCollection failed: $e');
      }
      rethrow;
    }
  }
}
