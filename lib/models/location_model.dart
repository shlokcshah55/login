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
    title = "${preference.toString()} Location - $name";
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
}

enum locationType { restaurant, hotel, museum, park, other }
enum locationPreference { saved, recommended, visited }

