import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:login/models/locations.dart';
import 'package:login/utils/geo_types.dart';

class MapboxPlaceSearchService {
  final http.Client _client;
  final String? _accessToken;

  MapboxPlaceSearchService({
    http.Client? client,
    String? accessToken,
  })  : _client = client ?? http.Client(),
        _accessToken = accessToken ?? dotenv.env['MAPBOX_ACCESS_TOKEN'];

  Future<List<LocationModel>> searchPlaces({
    required String query,
    LatLng? proximity,
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    final accessToken = _accessToken;
    if (trimmed.isEmpty || accessToken == null || accessToken.isEmpty) {
      return const [];
    }

    final queryParameters = <String, String>{
      'access_token': accessToken,
      'autocomplete': 'true',
      'limit': '$limit',
      'types': 'poi,address,place',
    };

    if (proximity != null) {
      queryParameters['proximity'] =
          '${proximity.longitude},${proximity.latitude}';
    }

    final uri = Uri.https(
      'api.mapbox.com',
      '/geocoding/v5/mapbox.places/${Uri.encodeComponent(trimmed)}.json',
      queryParameters,
    );

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>? ?? const [];

    return features.map((feature) {
      final featureMap = feature as Map<String, dynamic>;
      final center = featureMap['center'] as List<dynamic>? ?? const [];
      final longitude = center.isNotEmpty ? (center[0] as num).toDouble() : 0.0;
      final latitude = center.length > 1 ? (center[1] as num).toDouble() : 0.0;
      final name = featureMap['text']?.toString() ??
          featureMap['place_name']?.toString() ??
          trimmed;
      final fullName = featureMap['place_name']?.toString();
      final id = featureMap['id']?.toString() ?? name;
      final placeType = (featureMap['place_type'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .join(', ');

      return LocationModel(
        locationId: -id.hashCode.abs(),
        name: name,
        vicinity: fullName,
        lat: latitude,
        lng: longitude,
        createdAt: DateTime.now(),
        googlePlaceId: id,
        types: placeType,
      );
    }).toList();
  }
}
