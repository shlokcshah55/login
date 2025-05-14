import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../models/video_model.dart';
import '../supabase_client.dart';

/// Service for handling Supabase video operations
class SupabaseVideoService {
  final SupabaseClient _client = SupabaseClientManager().client;

  /// Submit a new video
  Future<VideoModel?> submitVideo(String url, String platform,
      {DateTime? createdAt, int? extractedLocationId}) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // First, find the user ID in your users table
      final userRecord = await _client
          .from('users')
          .select('user_id')
          .eq('supabase_id', user.id)
          .single();

      final userId = userRecord['user_id'];

      final videoData = {
        SupabaseConstants.columnUserId: userId,
        SupabaseConstants.columnPlatform: platform,
        SupabaseConstants.columnUrl: url,
        SupabaseConstants.columnCreatedAt:
            (createdAt ?? DateTime.now()).toIso8601String(),
      };

      if (extractedLocationId != null) {
        videoData[SupabaseConstants.columnExtractedLocationId] =
            extractedLocationId;
      }

      final response = await _client
          .from(SupabaseConstants.tableVideos)
          .insert(videoData)
          .select()
          .single();

      return VideoModel.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting video: $e');
      }
      return null;
    }
  }

  /// Get videos submitted by the current user
  Future<List<VideoModel>> getUserVideos() async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // First, find the user ID in your users table
      final userRecord = await _client
          .from('users')
          .select('user_id')
          .eq('supabase_id', user.id)
          .single();

      final userId = userRecord['user_id'];

      final response = await _client
          .from(SupabaseConstants.tableVideos)
          .select()
          .eq(SupabaseConstants.columnUserId, userId)
          .order(SupabaseConstants.columnCreatedAt, ascending: false);

      return (response as List)
          .map((data) => VideoModel.fromJson(data))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user videos: $e');
      }
      return [];
    }
  }

  /// Get videos for a specific location
  Future<List<VideoModel>> getVideosForLocation(int locationId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableVideos)
          .select()
          .eq(SupabaseConstants.columnExtractedLocationId, locationId)
          .order(SupabaseConstants.columnCreatedAt, ascending: false);

      return (response as List)
          .map((data) => VideoModel.fromJson(data))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting videos for location: $e');
      }
      return [];
    }
  }

  /// Share a video with a location (creates a user_location_action)
  Future<bool> shareVideoForLocation(String video_url, int locationId) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // First, find the user ID in your users table
      final userRecord = await _client
          .from('users')
          .select('user_id')
          .eq('supabase_id', user.id)
          .single();

      final userId = userRecord['user_id'];

      // Create the action
      await _client.from(SupabaseConstants.tableUserLocationActions).upsert({
        SupabaseConstants.columnUserId: userId,
        SupabaseConstants.columnLocationId: locationId,
        SupabaseConstants.columnAction: SupabaseConstants.actionSharedVideo,
        SupabaseConstants.columnSourceVideoUrl: video_url,
        SupabaseConstants.columnCreatedAt: DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing video for location: $e');
      }
      return false;
    }
  }

  /// Update a video with an extracted location
  Future<bool> updateVideoLocation(int videoId, int locationId) async {
    try {
      await _client.from(SupabaseConstants.tableVideos).update({
        SupabaseConstants.columnExtractedLocationId: locationId,
      }).eq(SupabaseConstants.columnVideoId, videoId);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating video location: $e');
      }
      return false;
    }
  }

  /// Delete a video
  Future<bool> deleteVideo(int videoId) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // First, find the user ID in your users table
      final userRecord = await _client
          .from('users')
          .select('user_id')
          .eq('supabase_id', user.id)
          .single();

      final userId = userRecord['user_id'];

      // Delete the video (only if it belongs to the user)
      await _client
          .from(SupabaseConstants.tableVideos)
          .delete()
          .eq(SupabaseConstants.columnVideoId, videoId)
          .eq(SupabaseConstants.columnUserId, userId);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting video: $e');
      }
      return false;
    }
  }
}
