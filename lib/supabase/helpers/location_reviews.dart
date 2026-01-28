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
      if (response is List && response.isNotEmpty) {
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
      if (response is List && response.isNotEmpty) {
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
}
