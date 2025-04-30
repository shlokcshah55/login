import '../constants.dart';

/// Model class for video data from Supabase
class VideoModel {
  final int? videoId;
  final int userId;
  final String platform;
  final String url;
  final int? extractedLocationId;
  final DateTime postedAt;
  final DateTime? createdAt;
  
  VideoModel({
    this.videoId,
    required this.userId,
    required this.platform,
    required this.url,
    this.extractedLocationId,
    required this.postedAt,
    this.createdAt,
  });

  /// Create a VideoModel from a JSON map
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      videoId: json[SupabaseConstants.columnVideoId],
      userId: json[SupabaseConstants.columnUserId],
      platform: json[SupabaseConstants.columnPlatform],
      url: json[SupabaseConstants.columnUrl],
      extractedLocationId: json[SupabaseConstants.columnExtractedLocationId],
      postedAt: DateTime.parse(json[SupabaseConstants.columnPostedAt]),
      createdAt: json[SupabaseConstants.columnCreatedAt] != null 
          ? DateTime.parse(json[SupabaseConstants.columnCreatedAt])
          : null,
    );
  }

  /// Convert VideoModel to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      SupabaseConstants.columnUserId: userId,
      SupabaseConstants.columnPlatform: platform,
      SupabaseConstants.columnUrl: url,
      SupabaseConstants.columnPostedAt: postedAt.toIso8601String(),
    };
    
    if (videoId != null) data[SupabaseConstants.columnVideoId] = videoId;
    if (extractedLocationId != null) data[SupabaseConstants.columnExtractedLocationId] = extractedLocationId;
    
    return data;
  }

  /// Create a copy of this VideoModel with updated fields
  VideoModel copyWith({
    int? videoId,
    int? userId,
    String? platform,
    String? url,
    int? extractedLocationId,
    DateTime? postedAt,
    DateTime? createdAt,
  }) {
    return VideoModel(
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      platform: platform ?? this.platform,
      url: url ?? this.url,
      extractedLocationId: extractedLocationId ?? this.extractedLocationId,
      postedAt: postedAt ?? this.postedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}