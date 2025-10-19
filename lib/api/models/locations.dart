import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:developer';

enum LocationType { restaurant, hotel, museum, park, other }

enum LocationPreference { saved, recommended, search }

/// Model class for location data from Supabase
class LocationModel {
  final int locationId;
  final String name;
  final String vicinity;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final String? phoneNumber;
  final String? cuisine;
  final double? rating;
  final int? userRatingsTotal;
  final int? priceLevel;
  final String? photoReference;
  final int? savedCount;
  LocationPreference? preference;

  LocationModel(
      {required this.locationId,
      required this.name,
      required this.vicinity,
      required this.lat,
      required this.lng,
      required this.createdAt,
      this.phoneNumber,
      this.cuisine,
      this.rating,
      this.userRatingsTotal,
      this.priceLevel,
      this.photoReference,
      this.savedCount,
      this.preference});

  /// Create a LocationModel from a JSON map
  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      locationId: json[SupabaseConstants.columnLocationId],
      name: json[SupabaseConstants.columnName],
      vicinity: json[SupabaseConstants.columnVicinity],
      lat: double.parse(json[SupabaseConstants.columnLat].toString()),
      lng: double.parse(json[SupabaseConstants.columnLng].toString()),
      createdAt: DateTime.parse(json[SupabaseConstants.columnCreatedAt]),
      phoneNumber: json[SupabaseConstants.columnPhoneNumber],
      cuisine: json[SupabaseConstants.columnCuisine],
      rating: json[SupabaseConstants.columnRating] != null
          ? double.parse(json[SupabaseConstants.columnRating].toString())
          : null,
      userRatingsTotal: json[SupabaseConstants.columnUserRatingsTotal],
      priceLevel: json[SupabaseConstants.columnPriceLevel],
      photoReference: json[SupabaseConstants.columnPhotoReference],
      savedCount: json[SupabaseConstants.columnSavedCount],
    );
  }


  factory LocationModel.fromJsonLocationNotification(
      Map<String, dynamic> json) {
    return LocationModel(
      locationId: json[SupabaseConstants.columnLocationId],
      name: json[SupabaseConstants.columnName],
      vicinity: json[SupabaseConstants.columnVicinity],
      lat: double.parse(json[SupabaseConstants.columnLat].toString()),
      lng: double.parse(json[SupabaseConstants.columnLng].toString()),
      createdAt: DateTime.parse(json[SupabaseConstants.columnCreatedAt]),
    );
  }

  /// Convert LocationModel to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      SupabaseConstants.columnLocationId: locationId,
      SupabaseConstants.columnName: name,
      SupabaseConstants.columnVicinity: vicinity,
      SupabaseConstants.columnLat: lat,
      SupabaseConstants.columnLng: lng,
      SupabaseConstants.columnCreatedAt: createdAt.toIso8601String(),
    };

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
  }) {
    return LocationModel(
      locationId: locationId ?? this.locationId,
      name: name ?? this.name,
      vicinity: vicinity ?? this.vicinity,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      cuisine: cuisine ?? this.cuisine,
      rating: rating ?? this.rating,
      userRatingsTotal: userRatingsTotal ?? this.userRatingsTotal,
      priceLevel: priceLevel ?? this.priceLevel,
      photoReference: photoReference ?? this.photoReference,
      savedCount: savedCount ?? this.savedCount,
    );
  }

  // UI helper fields that make this model compatible with the UI
  LatLng get position => LatLng(lat, lng);

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
      lat,
      lng,
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
  Marker toMarker() {
    return Marker(
      markerId: MarkerId(locationId.toString()),
      position: LatLng(lat, lng),
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: name,
        snippet: vicinity,
      ),
    );
  }
}
