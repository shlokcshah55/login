import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:googleapis/connectors/v1.dart';
import 'package:login/supabase/service.dart';

import '../supabase/constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:developer';
import 'dart:convert';

enum LocationType { restaurant, hotel, museum, park, other }

enum LocationPreference { saved, recommended, search }

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
  LocationPreference? preference;

  LocationModel(
    {required this.locationId,
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
    this.preference});

  factory LocationModel.fromJson(Map<String, dynamic> json, String? locationImage) {
    
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
          ? DateTime.tryParse(json[SupabaseConstants.columnIngestedAt].toString())
          : null,
      phoneNumber: json[SupabaseConstants.columnPhoneNumber],
      cuisine: json[SupabaseConstants.columnCuisine],
      rating: (json[SupabaseConstants.columnRating] as num?)?.toDouble(),
      userRatingsTotal: (json[SupabaseConstants.columnUserRatingsTotal] as num?)?.toInt(),
      priceLevel: (json[SupabaseConstants.columnPriceLevel] as num?)?.toInt(),
      photoReference: locationImage,
      savedCount: (json[SupabaseConstants.columnSavedCount] as num?)?.toInt(),
      googlePlaceId: json[SupabaseConstants.columnGooglePlaceId],
      businessStatus: json[SupabaseConstants.columnBusinessStatus],
      editorialSummary: json[SupabaseConstants.columnEditorialSummary],
      website: json[SupabaseConstants.columnWebsite],
      internationalPhoneNumber: json[SupabaseConstants.columnInternationalPhoneNumber],
      types: json[SupabaseConstants.columnTypes]?.toString(),
      

      // Correctly handle Postgres Arrays
      openingHoursText: json[SupabaseConstants.columnOpeningHoursText] != null
          ? List<String>.from(json[SupabaseConstants.columnOpeningHoursText])
          : null,
    
      
      openNow: json[SupabaseConstants.columnOpenNow] as bool?,
      cuisineDetected: json[SupabaseConstants.columnCuisineDetected],
      cuisineSource: json[SupabaseConstants.columnCuisineSource],
      cuisinePrimary: json[SupabaseConstants.columnCuisinePrimary],
      topReviewLanguage: json[SupabaseConstants.columnTopReviewLanguage],
      topLanguageShare: (json[SupabaseConstants.columnTopLanguageShare] as num?)?.toDouble(),
      
      reviewLanguageCountsJson: json[SupabaseConstants.columnReviewLanguageCountsJson],
      
      isOpenLate: json[SupabaseConstants.columnIsOpenLate] as bool?,
      isOpenEarly: json[SupabaseConstants.columnIsOpenEarly] as bool?,
      isSundayOpen: json[SupabaseConstants.columnIsSundayOpen] as bool?,
      priceBucket: json[SupabaseConstants.columnPriceBucket],
      logReviews: (json[SupabaseConstants.columnLogReviews] as num?)?.toDouble(),
      
      
      dataVersion: json[SupabaseConstants.columnDataVersion]?.toString() ?? 'v1',
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
    if (phoneNumber != null) data[SupabaseConstants.columnPhoneNumber] = phoneNumber;
    if (cuisine != null) data[SupabaseConstants.columnCuisine] = cuisine;
    if (rating != null) data[SupabaseConstants.columnRating] = rating;
    if (userRatingsTotal != null) data[SupabaseConstants.columnUserRatingsTotal] = userRatingsTotal;
    if (priceLevel != null) data[SupabaseConstants.columnPriceLevel] = priceLevel;
    if (photoReference != null) data[SupabaseConstants.columnPhotoReference] = photoReference;
    if (savedCount != null) data[SupabaseConstants.columnSavedCount] = savedCount;

    // Additional fields
    if (googlePlaceId != null) data[SupabaseConstants.columnGooglePlaceId] = googlePlaceId;
    if (businessStatus != null) data[SupabaseConstants.columnBusinessStatus] = businessStatus;
    if (editorialSummary != null) data[SupabaseConstants.columnEditorialSummary] = editorialSummary;
    if (website != null) data[SupabaseConstants.columnWebsite] = website;
    if (internationalPhoneNumber != null) data[SupabaseConstants.columnInternationalPhoneNumber] = internationalPhoneNumber;
    if (types != null) data[SupabaseConstants.columnTypes] = types;
    if (openingHoursText != null) data[SupabaseConstants.columnOpeningHoursText] = openingHoursText;
    if (openNow != null) data[SupabaseConstants.columnOpenNow] = openNow;
    if (cuisineDetected != null) data[SupabaseConstants.columnCuisineDetected] = cuisineDetected;
    if (cuisineSource != null) data[SupabaseConstants.columnCuisineSource] = cuisineSource;
    if (cuisinePrimary != null) data[SupabaseConstants.columnCuisinePrimary] = cuisinePrimary;
    if (topReviewLanguage != null) data[SupabaseConstants.columnTopReviewLanguage] = topReviewLanguage;
    if (topLanguageShare != null) data[SupabaseConstants.columnTopLanguageShare] = topLanguageShare;
    if (reviewLanguageCountsJson != null) data[SupabaseConstants.columnReviewLanguageCountsJson] = reviewLanguageCountsJson;
    if (isOpenLate != null) data[SupabaseConstants.columnIsOpenLate] = isOpenLate;
    if (isOpenEarly != null) data[SupabaseConstants.columnIsOpenEarly] = isOpenEarly;
    if (isSundayOpen != null) data[SupabaseConstants.columnIsSundayOpen] = isSundayOpen;
    if (priceBucket != null) data[SupabaseConstants.columnPriceBucket] = priceBucket;
    if (logReviews != null) data[SupabaseConstants.columnLogReviews] = logReviews;
    data[SupabaseConstants.columnDataVersion] = dataVersion;

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
    Map<String, dynamic>? openingHoursPeriods,
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
      savedCount: savedCount ?? this.savedCount,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      businessStatus: businessStatus ?? this.businessStatus,
      editorialSummary: editorialSummary ?? this.editorialSummary,
      website: website ?? this.website,
      internationalPhoneNumber: internationalPhoneNumber ?? this.internationalPhoneNumber,
      types: types ?? this.types,
      openingHoursText: openingHoursText ?? this.openingHoursText,
      openNow: openNow ?? this.openNow,
      cuisineDetected: cuisineDetected ?? this.cuisineDetected,
      cuisineSource: cuisineSource ?? this.cuisineSource,
      cuisinePrimary: cuisinePrimary ?? this.cuisinePrimary,
      topReviewLanguage: topReviewLanguage ?? this.topReviewLanguage,
      topLanguageShare: topLanguageShare ?? this.topLanguageShare,
      reviewLanguageCountsJson: reviewLanguageCountsJson ?? this.reviewLanguageCountsJson,
      isOpenLate: isOpenLate ?? this.isOpenLate,
      isOpenEarly: isOpenEarly ?? this.isOpenEarly,
      isSundayOpen: isSundayOpen ?? this.isSundayOpen,
      priceBucket: priceBucket ?? this.priceBucket,
      logReviews: logReviews ?? this.logReviews,
      dataVersion: dataVersion ?? this.dataVersion,
    );
  }

  // UI helper fields that make this model compatible with the UI
  LatLng? get position => (lat != null && lng != null) ? LatLng(lat!, lng!) : null;

  // Static marker icon for all locations
  static BitmapDescriptor? _customMarkerIcon;

  static Future<void> initializeCustomMarker() async {
    if (_customMarkerIcon == null) {
      _customMarkerIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'lib/assets/restaurant_pin.png',
      );
      log('LocationModel: Custom marker initialized');
    }
  }

  static double _degToRad(double deg) => deg * (math.pi / 180);

  /// Static method to check if a location is within a given radius
  bool isWithinRadius(int r, double currentLat, double currentLng) {
    // Return false if coordinates are not available
    if (lat == null || lng == null) return false;

    const double earthRadius = 6371; // Radius of the Earth in km

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

    // Calculate the distance from the current point to the location
    double distance = calculateDistance(
      lat!,
      lng!,
      currentLat,
      currentLng,
    );

    // Check if the distance is within the radius
    return distance <= r;
  }

  LocationModel setPreference(LocationPreference preference) {
    this.preference = preference;
    return this;
  }

  /// Creates a map marker from this location
  Marker? toMarker() {
    // Return null if coordinates are not available
    if (lat == null || lng == null) return null;

    return Marker(
      markerId: MarkerId(locationId.toString()),
      position: LatLng(lat!, lng!),
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: name,
        snippet: vicinity ?? '',
      ),
    );
  }


  
}
