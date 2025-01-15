import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationModel {
  String id;
  String name;
  String address;
  String description;
  double latitude;
  double longitude;
  locationPreference preference;

  // CarouselItem Fields 
  String? title;
  String? subtitle;
  
  // Marker fields 
  LatLng? position;

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

  Marker toMarker() {
    return Marker(
      markerId: MarkerId(id),
      position: LatLng(latitude, longitude),
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
      preference: locationPreference.saved,
    );
  }
}

enum locationType { restaurant, hotel, museum, park, other }
enum locationPreference { saved, recommended, visited }

extension LocationTypeExtension on locationType {
  String toShortString() {
    return this.toString().split('.').last;
  }
}

extension LocationPreferenceExtension on locationPreference {
  String toShortString() {
    return this.toString().split('.').last;
  }
}

