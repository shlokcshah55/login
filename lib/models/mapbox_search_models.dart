class MapboxSuggestion {
  final String name;
  final String mapboxId;
  final String? featureType;
  final String? address;
  final String? placeFormatted;
  final String? fullAddress;

  MapboxSuggestion({
    required this.name,
    required this.mapboxId,
    this.featureType,
    this.address,
    this.placeFormatted,
    this.fullAddress,
  });

  factory MapboxSuggestion.fromJson(Map<String, dynamic> json) {
    return MapboxSuggestion(
      name: json['name'] ?? '',
      mapboxId: json['mapbox_id'] ?? '',
      featureType: json['feature_type'],
      address: json['address'],
      placeFormatted: json['place_formatted'],
      fullAddress: json['full_address'],
    );
  }

  String get subtitle {
    if (placeFormatted != null && placeFormatted!.isNotEmpty) return placeFormatted!;
    if (fullAddress != null && fullAddress!.isNotEmpty) return fullAddress!;
    if (address != null && address!.isNotEmpty) return address!;
    return '';
  }
}

class MapboxPlaceDetails {
  final String mapboxId;
  final String name;
  final double latitude;
  final double longitude;
  final String? fullAddress;

  MapboxPlaceDetails({
    required this.mapboxId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.fullAddress,
  });

  factory MapboxPlaceDetails.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'] ?? {};
    final coordinates = json['geometry']?['coordinates'] as List<dynamic>?;
    
    double lng = 0.0;
    double lat = 0.0;
    if (coordinates != null && coordinates.length >= 2) {
      lng = (coordinates[0] as num).toDouble();
      lat = (coordinates[1] as num).toDouble();
    }

    return MapboxPlaceDetails(
      mapboxId: properties['mapbox_id'] ?? '',
      name: properties['name'] ?? '',
      latitude: lat,
      longitude: lng,
      fullAddress: properties['full_address'],
    );
  }
}
