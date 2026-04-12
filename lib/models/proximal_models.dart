class ProximalRequest {
  final String userId;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final int maxResults;
  final double qualityWeight;
  final double vibeWeight;
  final double dietaryWeight;
  final double socialWeight;
  final double collaborativeWeight;
  final bool includeTasteBreakdown;
  final Map<String, dynamic>? filters;

  const ProximalRequest({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    this.maxResults = 30,
    this.qualityWeight = 0.30,
    this.vibeWeight = 0.25,
    this.dietaryWeight = 0.10,
    this.socialWeight = 0.20,
    this.collaborativeWeight = 0.15,
    this.includeTasteBreakdown = false,
    this.filters,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
      'max_results': maxResults,
      'quality_weight': qualityWeight,
      'vibe_weight': vibeWeight,
      'dietary_weight': dietaryWeight,
      'social_weight': socialWeight,
      'collaborative_weight': collaborativeWeight,
      'include_taste_breakdown': includeTasteBreakdown,
    };

    if (filters != null && filters!.isNotEmpty) {
      json['filters'] = filters;
    }

    return json;
  }
}

class ProximalResponse {
  final String userId;
  final double centerLat;
  final double centerLon;
  final double radiusKm;
  final int totalResults;
  final List<Recommendation> recommendations;
  final String timestamp;

  const ProximalResponse({
    required this.userId,
    required this.centerLat,
    required this.centerLon,
    required this.radiusKm,
    required this.totalResults,
    required this.recommendations,
    required this.timestamp,
  });

  factory ProximalResponse.fromJson(Map<String, dynamic> json) {
    final recs = (json['recommendations'] as List<dynamic>? ?? [])
        .map((item) => Recommendation.fromJson(item as Map<String, dynamic>))
        .toList();
    return ProximalResponse(
      userId: json['user_id']?.toString() ?? '',
      centerLat: (json['center_lat'] as num?)?.toDouble() ?? 0,
      centerLon: (json['center_lon'] as num?)?.toDouble() ?? 0,
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 0,
      totalResults: (json['total_results'] as num?)?.toInt() ?? recs.length,
      recommendations: recs,
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }
}

class Recommendation {
  final int locationId;
  final String name;
  final String? vicinity;
  final String? cuisinePrimary;
  final double? rating;
  final int? userRatingsTotal;
  final int? priceLevel;
  final double? distanceKm;
  final double? tasteScore;
  final double? proximityScore;
  final double? qualityScore;
  final double? finalScore;
  final int? rank;
  final List<TasteBreakdown> tasteBreakdown;

  const Recommendation({
    required this.locationId,
    required this.name,
    this.vicinity,
    this.cuisinePrimary,
    this.rating,
    this.userRatingsTotal,
    this.priceLevel,
    this.distanceKm,
    this.tasteScore,
    this.proximityScore,
    this.qualityScore,
    this.finalScore,
    this.rank,
    this.tasteBreakdown = const [],
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      locationId: (json['location_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      vicinity: json['vicinity']?.toString(),
      cuisinePrimary: json['cuisine_primary']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: (json['user_ratings_total'] as num?)?.toInt(),
      priceLevel: (json['price_level'] as num?)?.toInt(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      tasteScore: (json['taste_score'] as num?)?.toDouble(),
      proximityScore: (json['proximity_score'] as num?)?.toDouble(),
      qualityScore: (json['quality_score'] as num?)?.toDouble(),
      finalScore: (json['final_score'] as num?)?.toDouble(),
      rank: (json['rank'] as num?)?.toInt(),
      tasteBreakdown: (json['taste_breakdown'] as List<dynamic>? ?? [])
          .map((item) => TasteBreakdown.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TasteBreakdown {
  final String tag;
  final double userScore;
  final double locationScore;
  final double contribution;

  const TasteBreakdown({
    required this.tag,
    required this.userScore,
    required this.locationScore,
    required this.contribution,
  });

  factory TasteBreakdown.fromJson(Map<String, dynamic> json) {
    return TasteBreakdown(
      tag: json['tag']?.toString() ?? '',
      userScore: (json['user_score'] as num?)?.toDouble() ?? 0,
      locationScore: (json['location_score'] as num?)?.toDouble() ?? 0,
      contribution: (json['contribution'] as num?)?.toDouble() ?? 0,
    );
  }
}
