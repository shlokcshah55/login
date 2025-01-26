import 'dart:developer';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationModel {
  String id;
  String name;
  String address;
  String description;
  double latitude;
  double longitude;
  LocationPreference preference;

  // CarouselItem Fields 
  String? title;
  String? subtitle;
  
  // Marker fields 
  LatLng? position;
  static BitmapDescriptor? _customMarkerIcon;

  LocationModel({
    required this.id,
    required this.name,
    required this.address,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.preference,
  }) {
    title = "${preference.toShortString()} Location - $name";
    subtitle = 'Location at ($latitude, $longitude)';
    position = LatLng(latitude, longitude);
  }
  
  static double _degToRad(double deg) => deg * (math.pi / 180);

  /// Static method to check if a location is within a given radius
  bool isWithinRadius(int r, double currentLat, double currentLng) {
    const double earthRadius = 6371; // Radius of the Earth in km

    double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
      double dLat = _degToRad(lat2 - lat1);
      double dLng = _degToRad(lng2 - lng1);

      double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
      double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return earthRadius * c;
    }


    // Calculate the distance from the current point to the location
    double distance = calculateDistance(
      latitude,
      longitude,
      currentLat,
      currentLng,
    );

    // Check if the distance is within the radius
    return distance <= r;
  }

  

  static Future<void> initializeCustomMarker() async {
    if (_customMarkerIcon == null) {
      _customMarkerIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'lib/assets/restaurant_pin.png',
      );
      log('LocationModel: Custom marker initialized');
    }
  }

  Marker toMarker() {
    return Marker(
      markerId: MarkerId(id),
      position: LatLng(latitude, longitude),
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: title,
        snippet: subtitle,
      ),
    );
  }

  factory LocationModel.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    log("LocationModel: fromDocument: $data");
    return LocationModel(
      id: doc.id,
      name: data['name'],
      address: "",
      description: "",
      latitude: data["location"].latitude,
      longitude: data['location'].longitude,
      preference: LocationPreference.saved,
    );
  }
}

enum LocationType { restaurant, hotel, museum, park, other }
enum LocationPreference { saved, recommended, visited }

extension LocationTypeExtension on LocationType {
  String toShortString() {
    return toString().split('.').last;
  }
}

extension LocationPreferenceExtension on LocationPreference {
  String toShortString() {
    return toString().split('.').last;
  }
}




