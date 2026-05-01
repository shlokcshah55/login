/// Model for video insights extracted from TikTok/Instagram videos
/// by the LLM pipeline. Stored in the `video_insights` table and
/// shared across all users who save the same video.
class VideoInsight {
  const VideoInsight({
    required this.id,
    required this.sourceVideoUrl,
    required this.locationId,
    this.keyDishes,
    this.creatorNotes,
    this.vibeSignals,
    this.sentiment,
    this.creatorHandle,
    this.videoDescription,
    this.extractedAt,
    this.extractionModel,
  });

  final String id;
  final String sourceVideoUrl;
  final int locationId;
  final List<DishHighlight>? keyDishes;
  final String? creatorNotes;
  final Map<String, double>? vibeSignals;
  final String? sentiment;
  final String? creatorHandle;
  final String? videoDescription;
  final DateTime? extractedAt;
  final String? extractionModel;

  factory VideoInsight.fromJson(Map<String, dynamic> json) {
    // Parse key_dishes from jsonb array
    List<DishHighlight>? dishes;
    final rawDishes = json['key_dishes'];
    if (rawDishes is List && rawDishes.isNotEmpty) {
      dishes = rawDishes
          .whereType<Map<String, dynamic>>()
          .map((d) => DishHighlight.fromJson(d))
          .toList();
    }

    // Parse vibe_signals from jsonb object
    Map<String, double>? vibes;
    final rawVibes = json['vibe_signals'];
    if (rawVibes is Map && rawVibes.isNotEmpty) {
      vibes = {};
      for (final entry in rawVibes.entries) {
        final val = entry.value;
        if (val is num) {
          vibes[entry.key.toString()] = val.toDouble();
        }
      }
    }

    return VideoInsight(
      id: json['id'] as String? ?? '',
      sourceVideoUrl: json['source_video_url'] as String? ?? '',
      locationId: (json['location_id'] as num?)?.toInt() ?? 0,
      keyDishes: dishes,
      creatorNotes: json['creator_notes'] as String?,
      vibeSignals: vibes,
      sentiment: json['sentiment'] as String?,
      creatorHandle: json['creator_handle'] as String?,
      videoDescription: json['video_description'] as String?,
      extractedAt: json['extracted_at'] != null
          ? DateTime.tryParse(json['extracted_at'] as String)
          : null,
      extractionModel: json['extraction_model'] as String?,
    );
  }
}

/// A single dish highlighted by the TikTok/Reel creator.
class DishHighlight {
  const DishHighlight({
    required this.name,
    this.description,
    this.price,
  });

  final String name;
  final String? description;
  final String? price;

  factory DishHighlight.fromJson(Map<String, dynamic> json) {
    return DishHighlight(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: json['price'] as String?,
    );
  }
}

/// Public social post linked to a location.
///
/// This is intentionally thumbnail-free: the UI displays creator/description
/// context from `video_insights` and opens the original source URL.
class SocialVideoPost {
  const SocialVideoPost({
    required this.sourceVideoUrl,
    this.creatorHandle,
    this.videoDescription,
    this.recommendedDish,
    this.shareCount = 1,
  });

  final String sourceVideoUrl;
  final String? creatorHandle;
  final String? videoDescription;
  final String? recommendedDish;
  final int shareCount;

  String get displayHandle {
    final handle = creatorHandle?.trim();
    if (handle == null || handle.isEmpty) return 'TikTok creator';
    return handle.startsWith('@') ? handle : '@$handle';
  }

  factory SocialVideoPost.fromInsight(
    VideoInsight insight, {
    int shareCount = 1,
  }) {
    String? dish;
    for (final highlight in insight.keyDishes ?? const <DishHighlight>[]) {
      final name = highlight.name.trim();
      if (name.isNotEmpty) {
        dish = name;
        break;
      }
    }

    return SocialVideoPost(
      sourceVideoUrl: insight.sourceVideoUrl,
      creatorHandle: insight.creatorHandle,
      videoDescription: insight.videoDescription,
      recommendedDish: dish,
      shareCount: shareCount,
    );
  }
}
