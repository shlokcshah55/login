import 'package:login/models/locations.dart';

/// Where a saved place came from. Social saves (TikTok / Instagram) carry a
/// creator's reason for saving, so they get boosted and richer copy.
enum ProximitySource {
  tiktok,
  instagram,
  inApp;

  bool get isSocial => this != inApp;

  String get label => switch (this) {
        tiktok => 'TikTok',
        instagram => 'Instagram',
        inApp => 'Pinit',
      };

  static ProximitySource fromSavedMethod(String? method) {
    switch (method?.toLowerCase()) {
      case 'tiktok':
        return tiktok;
      case 'instagram':
        return instagram;
      default:
        return inApp;
    }
  }
}

/// Social context for a saved place, joined from `video_insights` and
/// `social_post_places`. Every field is optional: older saves have none.
class ProximityInsight {
  const ProximityInsight({
    this.savedMethod,
    this.creatorHandle,
    this.topDish,
    this.vibe,
    this.confidenceTier,
    this.confirmedByUser = false,
    this.beenTo = false,
  });

  /// `tiktok`, `instagram` or `in-app`, from the latest save action.
  final String? savedMethod;
  final String? creatorHandle;
  final String? topDish;
  final String? vibe;

  /// `high`, `medium` or `low` from the share extraction. Null when unknown
  /// (legacy saves, in-app saves).
  final String? confidenceTier;
  final bool confirmedByUser;
  final bool beenTo;

  Map<String, dynamic> toJson() => {
        'saved_method': savedMethod,
        'creator_handle': creatorHandle,
        'top_dish': topDish,
        'vibe': vibe,
        'confidence_tier': confidenceTier,
        'confirmed_by_user': confirmedByUser,
        'been_to': beenTo,
      };

  factory ProximityInsight.fromJson(Map<String, dynamic> json) {
    String? clean(dynamic v) {
      final s = (v as String?)?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return ProximityInsight(
      savedMethod: clean(json['saved_method']),
      creatorHandle: clean(json['creator_handle']),
      topDish: clean(json['top_dish']),
      vibe: clean(json['vibe']),
      confidenceTier: clean(json['confidence_tier'])?.toLowerCase(),
      confirmedByUser: json['confirmed_by_user'] == true,
      beenTo: json['been_to'] == true,
    );
  }
}

/// A saved place the proximity system may notify about.
class ProximityCandidate {
  const ProximityCandidate({
    required this.locationId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.source = ProximitySource.inApp,
    this.insight = const ProximityInsight(),
    this.cuisine,
    this.rating,
    this.userRatingsTotal,
    this.openingHoursPeriods,
    this.openNow,
  });

  final int locationId;
  final String name;
  final double latitude;
  final double longitude;
  final ProximitySource source;
  final ProximityInsight insight;
  final String? cuisine;
  final double? rating;
  final int? userRatingsTotal;

  /// Google-style periods: `{open: {day, time: "HHMM"}, close: {...}}`.
  final List<dynamic>? openingHoursPeriods;
  final bool? openNow;

  bool get isSocial => source.isSocial;

  /// Compact form for the on-device snapshot used when the OS wakes the app
  /// before the saved list has loaded from the network.
  Map<String, dynamic> toJson() => {
        'id': locationId,
        'name': name,
        'lat': latitude,
        'lng': longitude,
        'source': source.name,
        'insight': insight.toJson(),
        'cuisine': cuisine,
        'rating': rating,
        'reviews': userRatingsTotal,
        'periods': openingHoursPeriods,
        'open_now': openNow,
      };

  static ProximityCandidate? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] as num?)?.toInt();
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    final name = raw['name'] as String?;
    if (id == null || lat == null || lng == null || name == null) return null;

    final insight = raw['insight'];
    return ProximityCandidate(
      locationId: id,
      name: name,
      latitude: lat,
      longitude: lng,
      source: ProximitySource.fromSavedMethod(raw['source'] as String?),
      insight: insight is Map
          ? ProximityInsight.fromJson(Map<String, dynamic>.from(insight))
          : const ProximityInsight(),
      cuisine: raw['cuisine'] as String?,
      rating: (raw['rating'] as num?)?.toDouble(),
      userRatingsTotal: (raw['reviews'] as num?)?.toInt(),
      openingHoursPeriods:
          raw['periods'] is List ? raw['periods'] as List : null,
      openNow: raw['open_now'] as bool?,
    );
  }

  /// Returns null when the place has no coordinates.
  static ProximityCandidate? fromLocation(
    LocationModel location, {
    ProximityInsight insight = const ProximityInsight(),
  }) {
    final lat = location.lat;
    final lng = location.lng;
    if (lat == null || lng == null) return null;

    return ProximityCandidate(
      locationId: location.locationId,
      name: location.name,
      latitude: lat,
      longitude: lng,
      source: ProximitySource.fromSavedMethod(
        location.savedMethod ?? insight.savedMethod,
      ),
      insight: insight,
      cuisine: location.cuisinePrimary ?? location.cuisine,
      rating: location.rating,
      userRatingsTotal: location.userRatingsTotal,
      openingHoursPeriods: location.openingHoursPeriods,
      openNow: location.openNow,
    );
  }
}
