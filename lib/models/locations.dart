import 'dart:math' as math;

import 'package:login/models/markers.dart';

import '../supabase/constants.dart';
import 'package:login/utils/geo_types.dart';

// ─────────────────────────────────────────────────────────────
//  Safe JSON helpers – prevent type-cast crashes from DB nulls / oddities
// ─────────────────────────────────────────────────────────────
bool? _safeBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return null;
}

List<T>? _safeList<T>(dynamic v, T Function(dynamic) cast) {
  if (v == null) return null;
  if (v is! List) return null;
  try {
    return v.map(cast).toList();
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _safeMap(dynamic v) {
  if (v == null) return null;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

// ─────────────────────────────────────────────────────────────
//  Vibe vector tag ordering (matches Python VIBE_TAG_ORDER)
// ─────────────────────────────────────────────────────────────
const Map<String, int> vibeTagOrder = {
  'cafe': 0,
  'casual': 1,
  'cozy': 2,
  'coffee_shop': 3,
  'bar': 4,
  'elegant': 5,
  'fine_dining': 6,
  'food_truck': 7,
  'hole_in_the_wall': 8,
  'late_night': 9,
  'live_music': 10,
  'michelin_starred': 11,
  'modern': 12,
  'fast_food': 13,
  'quiet': 14,
  'romantic': 15,
  'sports_bar': 16,
  'trendy': 17,
  'takeout_friendly': 18,
  'pub': 19,
  'grocery_store': 20,
  'brunch': 21,
  'outdoor_dining': 22,
  'wavy': 23,
  'bossman': 24,
};

final List<String> vibeTagsByIndex = (() {
  final tags = vibeTagOrder.keys.toList();
  tags.sort((a, b) => vibeTagOrder[a]!.compareTo(vibeTagOrder[b]!));
  return tags;
})();

/// Typed wrapper around a `vibe_vector real[]` from the DB.
class VibeVector {
  final List<double> values;

  const VibeVector(this.values);

  static List<double> _normalizeValues(List<double> rawValues) {
    return rawValues.map(_normalizeValue).toList(growable: false);
  }

  static double _normalizeValue(double raw) {
    if (!raw.isFinite) return 0.0;
    if (raw <= 0) return 0.0;
    if (raw <= 1.0) return raw;
    if (raw <= 100.0) return raw / 100.0;
    return 1.0;
  }

  factory VibeVector.fromDynamic(dynamic raw) {
    if (raw == null) return const VibeVector([]);
    if (raw is List) {
      return VibeVector(_normalizeValues(
        raw
            .map((e) =>
                e is num ? e.toDouble() : double.tryParse(e.toString()) ?? 0.0)
            .toList(),
      ));
    }
    // Postgres text form: {0.1,0.2,...}
    final s = raw.toString().replaceAll(RegExp(r'^\{|\}$'), '').trim();
    if (s.isEmpty) return const VibeVector([]);
    return VibeVector(
      _normalizeValues(
        s.split(',').map((e) => double.tryParse(e.trim()) ?? 0.0).toList(),
      ),
    );
  }

  double scoreFor(String tag) {
    final idx = vibeTagOrder[tag];
    if (idx == null || idx >= values.length) return 0.0;
    return values[idx];
  }

  /// Convenience getters for the two pinit-defining vibe dimensions.
  double get wavyScore => scoreFor('wavy');
  double get bossmanScore => scoreFor('bossman');

  List<MapEntry<String, double>> topTags([int n = 3]) {
    final pairs = <MapEntry<String, double>>[];
    for (var i = 0; i < values.length && i < vibeTagsByIndex.length; i++) {
      pairs.add(MapEntry(vibeTagsByIndex[i], values[i]));
    }
    pairs.sort((a, b) => b.value.compareTo(a.value));
    return pairs.take(n).toList();
  }

  List<double> toList() => values;

  @override
  String toString() => 'VibeVector(${values.length} tags)';
}

enum LocationType { restaurant, hotel, museum, park, other }

enum LocationPreference { saved, recommended, search, bubble }

/// Model class for location data from Supabase
class LocationModel {
  final int locationId;
  final String name;
  final String? vicinity;
  final double? lat;
  final double? lng;
  final DateTime createdAt;
  final String? phoneNumber;
  final String? cuisine;
  final double? rating;
  final int? userRatingsTotal;
  final int? priceLevel;
  final String? photoReference;
  final String? imageUrl; // Permanent Supabase Storage URL
  final int? savedCount;
  // Additional fields from the DB schema
  final DateTime? ingestedAt;
  final String? googlePlaceId;
  final String? businessStatus;
  final String? editorialSummary;
  final String? website;
  final String? internationalPhoneNumber;
  final String? types; // stored as text in DB, could be comma-separated
  final List<String>? openingHoursText;
  final bool? openNow;
  final String? cuisineDetected;
  final String? cuisineSource;
  final String? cuisinePrimary;
  final String? topReviewLanguage;
  final double? topLanguageShare;
  final Map<String, dynamic>? reviewLanguageCountsJson;
  final bool? isOpenLate;
  final bool? isOpenEarly;
  final bool? isSundayOpen;
  final String? priceBucket;
  final double? logReviews;
  final String dataVersion;
  final String? emoji;

  // ── Extended schema fields ──
  final List<dynamic>? openingHoursPeriods; // jsonb array of period objects
  final DateTime? photoReferenceValidUntil;
  final String? photoReferenceScore;
  final bool? imageStored;
  final bool? imageUnavailable;
  final int? extraPhotosStored;
  final DateTime? updatedAt;
  final String? googleMapsUri;
  final List<Map<String, dynamic>>? photos; // jsonb[]
  final List<Map<String, dynamic>>? reviews; // jsonb[]
  final String? reviewSummary;
  final bool? goodForChildren;
  final bool? goodForGroups;
  final bool? goodForWatchingSports;
  final bool? liveMusic;
  final bool? outdoorSeating;
  final bool? servesBeer;
  final bool? servesBreakfast;
  final bool? servesBrunch;
  final bool? servesCocktails;
  final bool? servesCoffee;
  final bool? servesDessert;
  final bool? servesDinner;
  final bool? servesLunch;
  final bool? servesVegetarianFood;
  final bool? servesWine;
  final String? menu;
  final String? generatedSummary;
  final String? recommendedDishes;
  final String? menuAnalysisConfidence;
  final List<double>? vibeVector;
  final VibeVector? vibe; // convenience wrapper
  final bool? updatedVibe;
  final bool? isTakeaway;
  final List<int>? dietaryRequirementVector;
  final Map<String, dynamic>? cuisineScoresJson;

  /// Computed match score (0-1) based on dot product of user affinities.
  /// Null if not yet computed or user has no affinity data.
  final double? matchScore;

  /// Source URL the user saved this location from (e.g. a TikTok link).
  /// Pulled from `user_location_actions.source_video_url` when this model
  /// is returned by a saved-locations query. Null in other contexts.
  final String? savedFrom;

  /// How the user saved this location (e.g. 'tiktok', 'in-app').
  /// Pulled from `user_location_actions.saved_method` when this model
  /// is returned by a saved-locations query. Null in other contexts.
  final String? savedMethod;

  LocationPreference? preference;

  LocationModel({
    required this.locationId,
    required this.name,
    this.vicinity,
    this.lat,
    this.lng,
    required this.createdAt,
    this.ingestedAt,
    this.phoneNumber,
    this.cuisine,
    this.rating,
    this.userRatingsTotal,
    this.priceLevel,
    this.photoReference,
    this.imageUrl,
    this.savedCount,
    this.googlePlaceId,
    this.businessStatus,
    this.editorialSummary,
    this.website,
    this.internationalPhoneNumber,
    this.types,
    this.openingHoursText,
    this.openNow,
    this.cuisineDetected,
    this.cuisineSource,
    this.cuisinePrimary,
    this.topReviewLanguage,
    this.topLanguageShare,
    this.reviewLanguageCountsJson,
    this.isOpenLate,
    this.isOpenEarly,
    this.isSundayOpen,
    this.priceBucket,
    this.logReviews,
    this.dataVersion = 'v1',
    this.emoji,
    this.preference,
    // Extended schema fields
    this.openingHoursPeriods,
    this.photoReferenceValidUntil,
    this.photoReferenceScore,
    this.imageStored,
    this.imageUnavailable,
    this.extraPhotosStored,
    this.updatedAt,
    this.googleMapsUri,
    this.photos,
    this.reviews,
    this.reviewSummary,
    this.goodForChildren,
    this.goodForGroups,
    this.goodForWatchingSports,
    this.liveMusic,
    this.outdoorSeating,
    this.servesBeer,
    this.servesBreakfast,
    this.servesBrunch,
    this.servesCocktails,
    this.servesCoffee,
    this.servesDessert,
    this.servesDinner,
    this.servesLunch,
    this.servesVegetarianFood,
    this.servesWine,
    this.menu,
    this.generatedSummary,
    this.recommendedDishes,
    this.menuAnalysisConfidence,
    this.vibeVector,
    this.vibe,
    this.updatedVibe,
    this.isTakeaway,
    this.dietaryRequirementVector,
    this.cuisineScoresJson,
    this.matchScore,
    this.savedFrom,
    this.savedMethod,
  });

  factory LocationModel.fromJson(
      Map<String, dynamic> json, String? locationImage) {
    return LocationModel(
      locationId: json[SupabaseConstants.columnLocationId] as int,
      name: json[SupabaseConstants.columnName] ?? 'Unknown',
      vicinity: json[SupabaseConstants.columnVicinity],
      lat: (json[SupabaseConstants.columnLat] as num?)?.toDouble(),
      lng: (json[SupabaseConstants.columnLng] as num?)?.toDouble(),
      createdAt: json[SupabaseConstants.columnCreatedAt] != null
          ? DateTime.parse(json[SupabaseConstants.columnCreatedAt])
          : DateTime.now(),
      ingestedAt: json[SupabaseConstants.columnIngestedAt] != null
          ? DateTime.tryParse(
              json[SupabaseConstants.columnIngestedAt].toString())
          : null,
      phoneNumber: json[SupabaseConstants.columnPhoneNumber],
      cuisine: json[SupabaseConstants.columnCuisine],
      rating: (json[SupabaseConstants.columnRating] as num?)?.toDouble(),
      userRatingsTotal:
          (json[SupabaseConstants.columnUserRatingsTotal] as num?)?.toInt(),
      priceLevel: (json[SupabaseConstants.columnPriceLevel] as num?)?.toInt(),
      photoReference: json[SupabaseConstants.columnPhotoReference],
      imageUrl:
          locationImage, // This comes from getLocationImage() - permanent Supabase URL
      savedCount: (json[SupabaseConstants.columnSavedCount] as num?)?.toInt(),
      googlePlaceId: json[SupabaseConstants.columnGooglePlaceId],
      businessStatus: json[SupabaseConstants.columnBusinessStatus],
      editorialSummary: json[SupabaseConstants.columnEditorialSummary],
      website: json[SupabaseConstants.columnWebsite],
      internationalPhoneNumber:
          json[SupabaseConstants.columnInternationalPhoneNumber],
      types: json[SupabaseConstants.columnTypes]?.toString(),

      // Correctly handle Postgres Arrays
      openingHoursText: json[SupabaseConstants.columnOpeningHoursText] != null
          ? List<String>.from(json[SupabaseConstants.columnOpeningHoursText])
          : null,

      openNow: _safeBool(json[SupabaseConstants.columnOpenNow]),
      cuisineDetected: json[SupabaseConstants.columnCuisineDetected],
      cuisineSource: json[SupabaseConstants.columnCuisineSource],
      cuisinePrimary: json[SupabaseConstants.columnCuisinePrimary],
      topReviewLanguage: json[SupabaseConstants.columnTopReviewLanguage],
      topLanguageShare:
          (json[SupabaseConstants.columnTopLanguageShare] as num?)?.toDouble(),

      reviewLanguageCountsJson:
          _safeMap(json[SupabaseConstants.columnReviewLanguageCountsJson]),

      isOpenLate: _safeBool(json[SupabaseConstants.columnIsOpenLate]),
      isOpenEarly: _safeBool(json[SupabaseConstants.columnIsOpenEarly]),
      isSundayOpen: _safeBool(json[SupabaseConstants.columnIsSundayOpen]),
      priceBucket: json[SupabaseConstants.columnPriceBucket],
      logReviews:
          (json[SupabaseConstants.columnLogReviews] as num?)?.toDouble(),

      dataVersion:
          json[SupabaseConstants.columnDataVersion]?.toString() ?? 'v1',
      emoji: json[SupabaseConstants.columnEmoji],

      // ── Extended schema fields (all defensively parsed) ──
      openingHoursPeriods:
          json[SupabaseConstants.columnOpeningHoursPeriods] is List
              ? List<dynamic>.from(
                  json[SupabaseConstants.columnOpeningHoursPeriods])
              : null,
      photoReferenceValidUntil:
          json[SupabaseConstants.columnPhotoReferenceValidUntil] != null
              ? DateTime.tryParse(
                  json[SupabaseConstants.columnPhotoReferenceValidUntil]
                      .toString())
              : null,
      photoReferenceScore:
          json[SupabaseConstants.columnPhotoReferenceScore]?.toString(),
      imageStored: _safeBool(json[SupabaseConstants.columnImageStored]),
      imageUnavailable:
          _safeBool(json[SupabaseConstants.columnImageUnavailable]),
      extraPhotosStored:
          (json[SupabaseConstants.columnExtraPhotosStored] as num?)?.toInt(),
      updatedAt: json[SupabaseConstants.columnUpdatedAt] != null
          ? DateTime.tryParse(
              json[SupabaseConstants.columnUpdatedAt].toString())
          : null,
      googleMapsUri: json[SupabaseConstants.columnGoogleMapsUri]?.toString(),
      photos: _safeList<Map<String, dynamic>>(
        json[SupabaseConstants.columnPhotos],
        (e) => Map<String, dynamic>.from(e as Map),
      ),
      reviews: _safeList<Map<String, dynamic>>(
        json[SupabaseConstants.columnReviews],
        (e) => Map<String, dynamic>.from(e as Map),
      ),
      reviewSummary: json[SupabaseConstants.columnReviewSummary]?.toString(),
      goodForChildren: _safeBool(json[SupabaseConstants.columnGoodForChildren]),
      goodForGroups: _safeBool(json[SupabaseConstants.columnGoodForGroups]),
      goodForWatchingSports:
          _safeBool(json[SupabaseConstants.columnGoodForWatchingSports]),
      liveMusic: _safeBool(json[SupabaseConstants.columnLiveMusic]),
      outdoorSeating: _safeBool(json[SupabaseConstants.columnOutdoorSeating]),
      servesBeer: _safeBool(json[SupabaseConstants.columnServesBeer]),
      servesBreakfast: _safeBool(json[SupabaseConstants.columnServesBreakfast]),
      servesBrunch: _safeBool(json[SupabaseConstants.columnServesBrunch]),
      servesCocktails: _safeBool(json[SupabaseConstants.columnServesCocktails]),
      servesCoffee: _safeBool(json[SupabaseConstants.columnServesCoffee]),
      servesDessert: _safeBool(json[SupabaseConstants.columnServesDessert]),
      servesDinner: _safeBool(json[SupabaseConstants.columnServesDinner]),
      servesLunch: _safeBool(json[SupabaseConstants.columnServesLunch]),
      servesVegetarianFood:
          _safeBool(json[SupabaseConstants.columnServesVegetarianFood]),
      servesWine: _safeBool(json[SupabaseConstants.columnServesWine]),
      menu: json[SupabaseConstants.columnMenu]?.toString(),
      generatedSummary:
          json[SupabaseConstants.columnGeneratedSummary]?.toString(),
      recommendedDishes:
          json[SupabaseConstants.columnRecommendedDishes]?.toString(),
      menuAnalysisConfidence:
          json[SupabaseConstants.columnMenuAnalysisConfidence]?.toString(),
      vibeVector: json[SupabaseConstants.columnVibeVector] != null
          ? VibeVector.fromDynamic(json[SupabaseConstants.columnVibeVector])
              .toList()
          : null,
      vibe: json[SupabaseConstants.columnVibeVector] != null
          ? VibeVector.fromDynamic(json[SupabaseConstants.columnVibeVector])
          : null,
      updatedVibe: _safeBool(json[SupabaseConstants.columnUpdatedVibe]),
      isTakeaway: _safeBool(json[SupabaseConstants.columnIsTakeaway]),
      dietaryRequirementVector: _safeList<int>(
        json[SupabaseConstants.columnDietaryRequirementVector],
        (e) => (e as num).toInt(),
      ),
      cuisineScoresJson:
          _safeMap(json[SupabaseConstants.columnCuisineScoresJson]),
      matchScore: null, // Set separately after fetching user affinity data
    );
  }

  factory LocationModel.fromJsonLocationNotification(
      Map<String, dynamic> json) {
    return LocationModel(
      locationId: json[SupabaseConstants.columnLocationId],
      name: json[SupabaseConstants.columnName],
      vicinity: json[SupabaseConstants.columnVicinity],
      lat: json[SupabaseConstants.columnLat] != null
          ? double.parse(json[SupabaseConstants.columnLat].toString())
          : null,
      lng: json[SupabaseConstants.columnLng] != null
          ? double.parse(json[SupabaseConstants.columnLng].toString())
          : null,
      createdAt: json[SupabaseConstants.columnCreatedAt] != null
          ? DateTime.parse(json[SupabaseConstants.columnCreatedAt])
          : DateTime.now(),
      emoji: json[SupabaseConstants.columnEmoji],
    );
  }

  /// Convert LocationModel to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      SupabaseConstants.columnLocationId: locationId,
      SupabaseConstants.columnName: name,
      SupabaseConstants.columnCreatedAt: createdAt.toIso8601String(),
    };

    if (vicinity != null) data[SupabaseConstants.columnVicinity] = vicinity;
    if (lat != null) data[SupabaseConstants.columnLat] = lat;
    if (lng != null) data[SupabaseConstants.columnLng] = lng;
    if (phoneNumber != null)
      data[SupabaseConstants.columnPhoneNumber] = phoneNumber;
    if (cuisine != null) data[SupabaseConstants.columnCuisine] = cuisine;
    if (rating != null) data[SupabaseConstants.columnRating] = rating;
    if (userRatingsTotal != null)
      data[SupabaseConstants.columnUserRatingsTotal] = userRatingsTotal;
    if (priceLevel != null)
      data[SupabaseConstants.columnPriceLevel] = priceLevel;
    if (photoReference != null)
      data[SupabaseConstants.columnPhotoReference] = photoReference;
    if (savedCount != null)
      data[SupabaseConstants.columnSavedCount] = savedCount;

    // Additional fields
    if (googlePlaceId != null)
      data[SupabaseConstants.columnGooglePlaceId] = googlePlaceId;
    if (businessStatus != null)
      data[SupabaseConstants.columnBusinessStatus] = businessStatus;
    if (editorialSummary != null)
      data[SupabaseConstants.columnEditorialSummary] = editorialSummary;
    if (website != null) data[SupabaseConstants.columnWebsite] = website;
    if (internationalPhoneNumber != null)
      data[SupabaseConstants.columnInternationalPhoneNumber] =
          internationalPhoneNumber;
    if (types != null) data[SupabaseConstants.columnTypes] = types;
    if (openingHoursText != null)
      data[SupabaseConstants.columnOpeningHoursText] = openingHoursText;
    if (openNow != null) data[SupabaseConstants.columnOpenNow] = openNow;
    if (cuisineDetected != null)
      data[SupabaseConstants.columnCuisineDetected] = cuisineDetected;
    if (cuisineSource != null)
      data[SupabaseConstants.columnCuisineSource] = cuisineSource;
    if (cuisinePrimary != null)
      data[SupabaseConstants.columnCuisinePrimary] = cuisinePrimary;
    if (topReviewLanguage != null)
      data[SupabaseConstants.columnTopReviewLanguage] = topReviewLanguage;
    if (topLanguageShare != null)
      data[SupabaseConstants.columnTopLanguageShare] = topLanguageShare;
    if (reviewLanguageCountsJson != null)
      data[SupabaseConstants.columnReviewLanguageCountsJson] =
          reviewLanguageCountsJson;
    if (isOpenLate != null)
      data[SupabaseConstants.columnIsOpenLate] = isOpenLate;
    if (isOpenEarly != null)
      data[SupabaseConstants.columnIsOpenEarly] = isOpenEarly;
    if (isSundayOpen != null)
      data[SupabaseConstants.columnIsSundayOpen] = isSundayOpen;
    if (priceBucket != null)
      data[SupabaseConstants.columnPriceBucket] = priceBucket;
    if (logReviews != null)
      data[SupabaseConstants.columnLogReviews] = logReviews;
    data[SupabaseConstants.columnDataVersion] = dataVersion;
    if (emoji != null) data[SupabaseConstants.columnEmoji] = emoji;

    // Extended schema fields
    if (openingHoursPeriods != null)
      data[SupabaseConstants.columnOpeningHoursPeriods] = openingHoursPeriods;
    if (photoReferenceValidUntil != null)
      data[SupabaseConstants.columnPhotoReferenceValidUntil] =
          photoReferenceValidUntil!.toIso8601String();
    if (photoReferenceScore != null)
      data[SupabaseConstants.columnPhotoReferenceScore] = photoReferenceScore;
    if (imageStored != null)
      data[SupabaseConstants.columnImageStored] = imageStored;
    if (updatedAt != null)
      data[SupabaseConstants.columnUpdatedAt] = updatedAt!.toIso8601String();
    if (googleMapsUri != null)
      data[SupabaseConstants.columnGoogleMapsUri] = googleMapsUri;
    if (photos != null) data[SupabaseConstants.columnPhotos] = photos;
    if (reviews != null) data[SupabaseConstants.columnReviews] = reviews;
    if (reviewSummary != null)
      data[SupabaseConstants.columnReviewSummary] = reviewSummary;
    if (goodForChildren != null)
      data[SupabaseConstants.columnGoodForChildren] = goodForChildren;
    if (goodForGroups != null)
      data[SupabaseConstants.columnGoodForGroups] = goodForGroups;
    if (goodForWatchingSports != null)
      data[SupabaseConstants.columnGoodForWatchingSports] =
          goodForWatchingSports;
    if (liveMusic != null) data[SupabaseConstants.columnLiveMusic] = liveMusic;
    if (outdoorSeating != null)
      data[SupabaseConstants.columnOutdoorSeating] = outdoorSeating;
    if (servesBeer != null)
      data[SupabaseConstants.columnServesBeer] = servesBeer;
    if (servesBreakfast != null)
      data[SupabaseConstants.columnServesBreakfast] = servesBreakfast;
    if (servesBrunch != null)
      data[SupabaseConstants.columnServesBrunch] = servesBrunch;
    if (servesCocktails != null)
      data[SupabaseConstants.columnServesCocktails] = servesCocktails;
    if (servesCoffee != null)
      data[SupabaseConstants.columnServesCoffee] = servesCoffee;
    if (servesDessert != null)
      data[SupabaseConstants.columnServesDessert] = servesDessert;
    if (servesDinner != null)
      data[SupabaseConstants.columnServesDinner] = servesDinner;
    if (servesLunch != null)
      data[SupabaseConstants.columnServesLunch] = servesLunch;
    if (servesVegetarianFood != null)
      data[SupabaseConstants.columnServesVegetarianFood] = servesVegetarianFood;
    if (servesWine != null)
      data[SupabaseConstants.columnServesWine] = servesWine;
    if (menu != null) data[SupabaseConstants.columnMenu] = menu;
    if (generatedSummary != null)
      data[SupabaseConstants.columnGeneratedSummary] = generatedSummary;
    if (recommendedDishes != null)
      data[SupabaseConstants.columnRecommendedDishes] = recommendedDishes;
    if (menuAnalysisConfidence != null)
      data[SupabaseConstants.columnMenuAnalysisConfidence] =
          menuAnalysisConfidence;
    if (vibeVector != null)
      data[SupabaseConstants.columnVibeVector] = vibeVector;
    if (updatedVibe != null)
      data[SupabaseConstants.columnUpdatedVibe] = updatedVibe;
    if (isTakeaway != null)
      data[SupabaseConstants.columnIsTakeaway] = isTakeaway;
    if (dietaryRequirementVector != null)
      data[SupabaseConstants.columnDietaryRequirementVector] =
          dietaryRequirementVector;
    if (cuisineScoresJson != null)
      data[SupabaseConstants.columnCuisineScoresJson] = cuisineScoresJson;

    return data;
  }

  /// Create a copy of this LocationModel with updated fields
  LocationModel copyWith({
    int? locationId,
    String? name,
    String? vicinity,
    double? lat,
    double? lng,
    DateTime? createdAt,
    String? phoneNumber,
    String? cuisine,
    double? rating,
    int? userRatingsTotal,
    int? priceLevel,
    String? photoReference,
    String? imageUrl,
    int? savedCount,
    bool clearVicinity = false,
    bool clearLat = false,
    bool clearLng = false,
    String? googlePlaceId,
    String? businessStatus,
    String? editorialSummary,
    String? website,
    String? internationalPhoneNumber,
    String? types,
    List<String>? openingHoursText,
    List<dynamic>? openingHoursPeriods,
    bool? openNow,
    String? cuisineDetected,
    String? cuisineSource,
    String? cuisinePrimary,
    String? topReviewLanguage,
    double? topLanguageShare,
    Map<String, dynamic>? reviewLanguageCountsJson,
    bool? isOpenLate,
    bool? isOpenEarly,
    bool? isSundayOpen,
    String? priceBucket,
    double? logReviews,
    Map<String, dynamic>? derivedAttributes,
    String? dataVersion,
    String? emoji,
    // Extended schema fields
    DateTime? photoReferenceValidUntil,
    String? photoReferenceScore,
    bool? imageStored,
    bool? imageUnavailable,
    int? extraPhotosStored,
    DateTime? updatedAt,
    String? googleMapsUri,
    List<Map<String, dynamic>>? photos,
    List<Map<String, dynamic>>? reviews,
    String? reviewSummary,
    bool? goodForChildren,
    bool? goodForGroups,
    bool? goodForWatchingSports,
    bool? liveMusic,
    bool? outdoorSeating,
    bool? servesBeer,
    bool? servesBreakfast,
    bool? servesBrunch,
    bool? servesCocktails,
    bool? servesCoffee,
    bool? servesDessert,
    bool? servesDinner,
    bool? servesLunch,
    bool? servesVegetarianFood,
    bool? servesWine,
    String? menu,
    String? generatedSummary,
    String? recommendedDishes,
    String? menuAnalysisConfidence,
    List<double>? vibeVector,
    VibeVector? vibe,
    bool? updatedVibe,
    bool? isTakeaway,
    List<int>? dietaryRequirementVector,
    Map<String, dynamic>? cuisineScoresJson,
    double? matchScore,
    String? savedFrom,
    String? savedMethod,
  }) {
    return LocationModel(
      locationId: locationId ?? this.locationId,
      name: name ?? this.name,
      vicinity: clearVicinity ? null : (vicinity ?? this.vicinity),
      lat: clearLat ? null : (lat ?? this.lat),
      lng: clearLng ? null : (lng ?? this.lng),
      createdAt: createdAt ?? this.createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      cuisine: cuisine ?? this.cuisine,
      rating: rating ?? this.rating,
      userRatingsTotal: userRatingsTotal ?? this.userRatingsTotal,
      priceLevel: priceLevel ?? this.priceLevel,
      photoReference: photoReference ?? this.photoReference,
      imageUrl: imageUrl ?? this.imageUrl,
      savedCount: savedCount ?? this.savedCount,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      businessStatus: businessStatus ?? this.businessStatus,
      editorialSummary: editorialSummary ?? this.editorialSummary,
      website: website ?? this.website,
      internationalPhoneNumber:
          internationalPhoneNumber ?? this.internationalPhoneNumber,
      types: types ?? this.types,
      openingHoursText: openingHoursText ?? this.openingHoursText,
      openNow: openNow ?? this.openNow,
      cuisineDetected: cuisineDetected ?? this.cuisineDetected,
      cuisineSource: cuisineSource ?? this.cuisineSource,
      cuisinePrimary: cuisinePrimary ?? this.cuisinePrimary,
      topReviewLanguage: topReviewLanguage ?? this.topReviewLanguage,
      topLanguageShare: topLanguageShare ?? this.topLanguageShare,
      reviewLanguageCountsJson:
          reviewLanguageCountsJson ?? this.reviewLanguageCountsJson,
      isOpenLate: isOpenLate ?? this.isOpenLate,
      isOpenEarly: isOpenEarly ?? this.isOpenEarly,
      isSundayOpen: isSundayOpen ?? this.isSundayOpen,
      priceBucket: priceBucket ?? this.priceBucket,
      logReviews: logReviews ?? this.logReviews,
      dataVersion: dataVersion ?? this.dataVersion,
      emoji: emoji ?? this.emoji,
      // Extended schema fields
      openingHoursPeriods: openingHoursPeriods ?? this.openingHoursPeriods,
      photoReferenceValidUntil:
          photoReferenceValidUntil ?? this.photoReferenceValidUntil,
      photoReferenceScore: photoReferenceScore ?? this.photoReferenceScore,
      imageStored: imageStored ?? this.imageStored,
      imageUnavailable: imageUnavailable ?? this.imageUnavailable,
      extraPhotosStored: extraPhotosStored ?? this.extraPhotosStored,
      updatedAt: updatedAt ?? this.updatedAt,
      googleMapsUri: googleMapsUri ?? this.googleMapsUri,
      photos: photos ?? this.photos,
      reviews: reviews ?? this.reviews,
      reviewSummary: reviewSummary ?? this.reviewSummary,
      goodForChildren: goodForChildren ?? this.goodForChildren,
      goodForGroups: goodForGroups ?? this.goodForGroups,
      goodForWatchingSports:
          goodForWatchingSports ?? this.goodForWatchingSports,
      liveMusic: liveMusic ?? this.liveMusic,
      outdoorSeating: outdoorSeating ?? this.outdoorSeating,
      servesBeer: servesBeer ?? this.servesBeer,
      servesBreakfast: servesBreakfast ?? this.servesBreakfast,
      servesBrunch: servesBrunch ?? this.servesBrunch,
      servesCocktails: servesCocktails ?? this.servesCocktails,
      servesCoffee: servesCoffee ?? this.servesCoffee,
      servesDessert: servesDessert ?? this.servesDessert,
      servesDinner: servesDinner ?? this.servesDinner,
      servesLunch: servesLunch ?? this.servesLunch,
      servesVegetarianFood: servesVegetarianFood ?? this.servesVegetarianFood,
      servesWine: servesWine ?? this.servesWine,
      menu: menu ?? this.menu,
      generatedSummary: generatedSummary ?? this.generatedSummary,
      recommendedDishes: recommendedDishes ?? this.recommendedDishes,
      menuAnalysisConfidence:
          menuAnalysisConfidence ?? this.menuAnalysisConfidence,
      vibeVector: vibeVector ?? this.vibeVector,
      vibe: vibe ?? this.vibe,
      updatedVibe: updatedVibe ?? this.updatedVibe,
      isTakeaway: isTakeaway ?? this.isTakeaway,
      dietaryRequirementVector:
          dietaryRequirementVector ?? this.dietaryRequirementVector,
      cuisineScoresJson: cuisineScoresJson ?? this.cuisineScoresJson,
      matchScore: matchScore ?? this.matchScore,
      savedFrom: savedFrom ?? this.savedFrom,
      savedMethod: savedMethod ?? this.savedMethod,
    );
  }

  // UI helper fields that make this model compatible with the UI
  LatLng? get position =>
      (lat != null && lng != null) ? LatLng(lat!, lng!) : null;

  // ─────────────────────────────────────────────────────────────
  //  Match scoring – calculates fit between user affinity and location
  // ─────────────────────────────────────────────────────────────

  /// Calculate composite match score (0-1) from user affinity vectors.
  /// Uses weighted sum of vibe and dietary match scores.
  /// Returns 0.0 if user has no affinity data or location lacks vectors.
  static double calculateMatchScore({
    required List<double>? userVibeAffinity,
    required List<int>? userDietaryAffinity,
    required List<double>? locationVibeVector,
    required List<int>? locationDietaryVector,
    double vibeWeight = 0.6,
    double dietaryWeight = 0.4,
  }) {
    if ((userVibeAffinity == null || userVibeAffinity.isEmpty) &&
        (userDietaryAffinity == null || userDietaryAffinity.isEmpty)) {
      return 0.0;
    }

    double vibeScore = 0.0;
    double dietaryScore = 0.0;

    // Vibe match: cosine similarity between user affinity and location vector.
    if (userVibeAffinity != null &&
        userVibeAffinity.isNotEmpty &&
        locationVibeVector != null &&
        locationVibeVector.isNotEmpty) {
      double dot = 0, magA = 0, magB = 0;
      final len = math.min(userVibeAffinity.length, locationVibeVector.length);
      for (var i = 0; i < len; i++) {
        final a = userVibeAffinity[i];
        final b = locationVibeVector[i];
        dot += a * b;
        magA += a * a;
        magB += b * b;
      }
      if (magA > 0 && magB > 0) {
        vibeScore = dot / (math.sqrt(magA) * math.sqrt(magB));
        // Normalize cosine similarity [−1, 1] to [0, 1]
        vibeScore = (vibeScore + 1) / 2;
      }
    }

    // Dietary match: same logic but both are int lists
    if (userDietaryAffinity != null &&
        userDietaryAffinity.isNotEmpty &&
        locationDietaryVector != null &&
        locationDietaryVector.isNotEmpty) {
      double dot = 0, magA = 0, magB = 0;
      final len =
          math.min(userDietaryAffinity.length, locationDietaryVector.length);
      for (var i = 0; i < len; i++) {
        final a = userDietaryAffinity[i].toDouble();
        final b = locationDietaryVector[i].toDouble();
        dot += a * b;
        magA += a * a;
        magB += b * b;
      }
      if (magA > 0 && magB > 0) {
        dietaryScore = dot / (math.sqrt(magA) * math.sqrt(magB));
        dietaryScore = (dietaryScore + 1) / 2;
      }
    }

    // Weighted combination
    if (userVibeAffinity != null && userVibeAffinity.isNotEmpty) {
      if (userDietaryAffinity != null && userDietaryAffinity.isNotEmpty) {
        // Both available, combine
        return vibeScore * vibeWeight + dietaryScore * dietaryWeight;
      } else {
        // Only vibe, return vibe score normalized by weight
        return vibeScore * (vibeWeight / (vibeWeight + dietaryWeight));
      }
    } else {
      // Only dietary available
      return dietaryScore * (dietaryWeight / (vibeWeight + dietaryWeight));
    }
  }

  static Future<void> initializeCustomMarker() async {
    // No-op for Mapbox — custom markers are rendered per-annotation
  }

  static double _degToRad(double deg) => deg * (math.pi / 180);

  /// Static method to check if a location is within a given radius
  bool isWithinRadius(int r, double currentLat, double currentLng) {
    if (lat == null || lng == null) return false;

    const double earthRadius = 6371;

    double calculateDistance(
        double lat1, double lng1, double lat2, double lng2) {
      double dLat = _degToRad(lat2 - lat1);
      double dLng = _degToRad(lng2 - lng1);

      double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(_degToRad(lat1)) *
              math.cos(_degToRad(lat2)) *
              math.sin(dLng / 2) *
              math.sin(dLng / 2);
      double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return earthRadius * c;
    }

    double distance = calculateDistance(
      lat!,
      lng!,
      currentLat,
      currentLng,
    );

    return distance <= r;
  }

  LocationModel setPreference(LocationPreference preference) {
    this.preference = preference;
    return this;
  }

  String? _formatTopVibeTag(String rawTag) {
    switch (rawTag) {
      case 'coffee_shop':
        return 'coffee shop';
      case 'fine_dining':
        return 'fine dining';
      case 'hole_in_the_wall':
        return 'hidden spot';
      case 'takeout_friendly':
        return 'takeout';
      case 'late_night':
        return 'late night';
      case 'live_music':
        return 'live music';
      case 'outdoor_dining':
        return 'outdoor';
      default:
        return rawTag.replaceAll('_', ' ');
    }
  }

  String? get topVibeTagLabel {
    final tags = vibe?.topTags(5) ?? <MapEntry<String, double>>[];
    for (final tag in tags) {
      if (tag.value < 0.22) continue;
      if (tag.key == 'wavy' || tag.key == 'bossman') continue;
      return _formatTopVibeTag(tag.key);
    }
    return null;
  }

  String? get markerBadgeType {
    if ((matchScore ?? 0.0) > 0.7) {
      return PinitMarkerBadgeType.sparkle;
    }
    if (liveMusic == true) {
      return PinitMarkerBadgeType.liveMusic;
    }
    if (servesCocktails == true) {
      return PinitMarkerBadgeType.cocktails;
    }
    if (outdoorSeating == true) {
      return PinitMarkerBadgeType.outdoor;
    }
    if ((savedCount ?? 0) > 10) {
      return PinitMarkerBadgeType.trending;
    }
    if (isOpenLate == true) {
      return PinitMarkerBadgeType.late;
    }
    return null;
  }

  /// Creates map marker data from this location.
  /// Returns [MapMarkerData] containing the rendered PNG bytes for Mapbox annotation.
  ///
  /// Vibe scores (wavy / bossman) and [savedCount] are extracted from the
  /// model and forwarded to the marker renderer so that:
  ///  • Wavy places get an iridescent shimmer ring + colour-fringe glow
  ///  • Bossman places are visually de-saturated / muted
  ///  • High saved-count places glow more intensely
  Future<MapMarkerData?> toMarker(double dpr,
      {bool shouldShowName = true}) async {
    if (lat == null || lng == null) return null;

    // Extract vibe scores — default to 0 when vector is absent.
    final double wavyScore = vibe?.wavyScore ?? 0.0;
    final double bossmanScore = vibe?.bossmanScore ?? 0.0;

    final imageBytes = await PinitMarkers.createPinitMarker(
      emoji: emoji,
      name: name,
      devicePixelRatio: dpr,
      types: types,
      cuisine: cuisine,
      showText: shouldShowName,
      wavyScore: wavyScore,
      bossmanScore: bossmanScore,
      savedCount: savedCount ?? 0,
      matchScore: matchScore ?? 0.0,
      badgeType: markerBadgeType,
      rating: rating,
      vibeVector: vibeVector,
      fallbackSeed: locationId,
    );

    return MapMarkerData(
      id: locationId.toString(),
      position: LatLng(lat!, lng!),
      imageBytes: imageBytes,
      title: name,
      snippet: vicinity ?? '',
    );
  }
}
