import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:login/models/video_insights.dart';
import 'package:login/supabase/supabase_client.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper for fetching and managing video insights from Supabase.
class VideoInsightsHelper {
  VideoInsightsHelper()
      : _client = SupabaseClientManager().client;

  final SupabaseClient _client;

  /// Fetch the video insight matching a specific source URL and location.
  /// Returns null if no insight exists for this combination.
  Future<VideoInsight?> getInsight({
    required int locationId,
    required String sourceVideoUrl,
  }) async {
    try {
      final response = await _client
          .from('video_insights')
          .select()
          .eq('location_id', locationId)
          .eq('source_video_url', sourceVideoUrl)
          .maybeSingle();

      if (response == null) return null;
      return VideoInsight.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      developer.log(
        '[VideoInsights] Error fetching insight: $e',
        name: 'VideoInsightsHelper',
      );
      return null;
    }
  }

  /// Fetch all video insights for a given location (multi-TikTok case).
  Future<List<VideoInsight>> getInsightsForLocation(int locationId) async {
    try {
      final response = await _client
          .from('video_insights')
          .select()
          .eq('location_id', locationId);

      if (response == null) return [];
      return (response as List)
          .map((row) =>
              VideoInsight.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('[VideoInsights] Error fetching insights for location: $e');
      }
      return [];
    }
  }
}
