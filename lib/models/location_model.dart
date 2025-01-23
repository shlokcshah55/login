import 'dart:developer';

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
  final double? rating;
  final int? userRatingsTotal;
  final int? priceLevel;
  final String? vicinity;
  final String? photoReference;

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
    this.rating,
    this.userRatingsTotal,
    this.priceLevel,
    this.vicinity,
    this.photoReference,
  }) {
    title = "${preference.toShortString()} Location - $name";
    subtitle = 'Location at ($latitude, $longitude)';
    position = LatLng(latitude, longitude);
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

