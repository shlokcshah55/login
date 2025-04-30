import 'package:flutter/foundation.dart';

import '../models/video_model.dart';
import '../services/supabase_video_service.dart';

/// Repository for video-related operations
class VideoRepository {
  final SupabaseVideoService _videoService = SupabaseVideoService();
  
  /// Submit a new video
  Future<VideoModel?> submitVideo(
    String url, 
    String platform, 
    {DateTime? postedAt, int? extractedLocationId}
  ) async {
    try {
      return await _videoService.submitVideo(
        url, 
        platform,
        postedAt: postedAt,
        extractedLocationId: extractedLocationId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error in VideoRepository.submitVideo: $e');
      }
      return null;
    }
  }

  /// Get videos for the current user
  Future<List<VideoModel>> getUserVideos() async {
    try {
      return await _videoService.getUserVideos();
    } catch (e) {
      if (kDebugMode) {
        print('Error in VideoRepository.getUserVideos: $e');
      }
      return [];
    }
  }

  /// Get videos for a specific location
  Future<List<VideoModel>> getVideosForLocation(int locationId) async {
    try {
      return await _videoService.getVideosForLocation(locationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error in VideoRepository.getVideosForLocation: $e');
      }
      return [];
    }
  }

  /// Share a video for a location
  Future<bool> shareVideoForLocation(int videoId, int locationId) async {
    try {
      return await _videoService.shareVideoForLocation(videoId, locationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error in VideoRepository.shareVideoForLocation: $e');
      }
      return false;
    }
  }

  /// Update a video with extracted location
  Future<bool> updateVideoLocation(int videoId, int locationId) async {
    try {
      return await _videoService.updateVideoLocation(videoId, locationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error in VideoRepository.updateVideoLocation: $e');
      }
      return false;
    }
  }

  /// Delete a video
  Future<bool> deleteVideo(int videoId) async {
    try {
      return await _videoService.deleteVideo(videoId);
    } catch (e) {
      if (kDebugMode) {
        print('Error in VideoRepository.deleteVideo: $e');
      }
      return false;
    }
  }
}