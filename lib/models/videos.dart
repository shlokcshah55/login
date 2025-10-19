import '../supabase/constants.dart';

/// Model class for video data from Supabase
class VideoModel {
  final int? videoId;
  final int userId;
  final String platform;
  final String url;
  final int? extractedLocationId;
  final DateTime? createdAt;

  VideoModel({
    this.videoId,
    required this.userId,
    required this.platform,
    required this.url,
    this.extractedLocationId,
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
    };

    if (videoId != null) data[SupabaseConstants.columnVideoId] = videoId;
    if (extractedLocationId != null)
      data[SupabaseConstants.columnExtractedLocationId] = extractedLocationId;

    return data;
  }

  /// Create a copy of this VideoModel with updated fields
  VideoModel copyWith({
    int? videoId,
    int? userId,
    String? platform,
    String? url,
    int? extractedLocationId,
    DateTime? createdAt,
  }) {
    return VideoModel(
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      platform: platform ?? this.platform,
      url: url ?? this.url,
      extractedLocationId: extractedLocationId ?? this.extractedLocationId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
