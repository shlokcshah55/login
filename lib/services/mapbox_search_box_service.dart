import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:login/models/locations.dart';
import 'package:login/utils/geo_types.dart';

/// A lightweight stub returned by Mapbox `/suggest` — no coordinates yet.
/// Coordinates are fetched lazily via [MapboxSearchBoxService.retrieve] when
/// the user taps the suggestion.
class MapboxSuggestion {
  final String mapboxId;
  final String name;
  final String? placeFormatted;
  final String? featureType;
  final String? address;
  final double? distanceMeters;
  final String? poiCategory;

  const MapboxSuggestion({
    required this.mapboxId,
    required this.name,
    this.placeFormatted,
    this.featureType,
    this.address,
    this.distanceMeters,
    this.poiCategory,
  });
}

/// Wraps Mapbox's Search Box API (`/search/searchbox/v1/suggest` and
/// `/search/searchbox/v1/retrieve`) for real-time autocomplete.
///
/// Session-token lifecycle is owned by the caller — the same token must be
/// passed to every `/suggest` call in a session and to the final `/retrieve`,
/// then rotated. See https://docs.mapbox.com/api/search/search-box/.
class MapboxSearchBoxService {
  final http.Client _client;
  final String? _accessToken;

  MapboxSearchBoxService({
    http.Client? client,
    String? accessToken,
  })  : _client = client ?? http.Client(),
        _accessToken = accessToken ?? dotenv.env['MAPBOX_ACCESS_TOKEN'];

  /// Cheap autocomplete. Returns suggestion stubs without coordinates.
  Future<List<MapboxSuggestion>> suggest({
    required String query,
    required String sessionToken,
    LatLng? proximity,
    int limit = 6,
    String types = 'poi,address,place',
    String? country,
    String language = 'en',
  }) async {
    final trimmed = query.trim();
    final accessToken = _accessToken;
    if (trimmed.isEmpty || accessToken == null || accessToken.isEmpty) {
      return const [];
    }

    final params = <String, String>{
      'q': trimmed,
      'access_token': accessToken,
      'session_token': sessionToken,
      'limit': '$limit',
      'types': types,
      'language': language,
    };
    if (proximity != null) {
      params['proximity'] =
          '${proximity.longitude},${proximity.latitude}';
    }
    if (country != null && country.isNotEmpty) {
      params['country'] = country;
    }

    final uri = Uri.https(
      'api.mapbox.com',
      '/search/searchbox/v1/suggest',
      params,
    );

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = decoded['suggestions'] as List<dynamic>? ?? const [];

    return suggestions
        .whereType<Map<String, dynamic>>()
        .map(_parseSuggestion)
        .whereType<MapboxSuggestion>()
        .toList();
  }

  /// Resolves a tapped suggestion to a [LocationModel] with coordinates.
  /// Must use the same [sessionToken] as the preceding `/suggest` call.
  Future<LocationModel?> retrieve({
    required String mapboxId,
    required String sessionToken,
  }) async {
    final accessToken = _accessToken;
    if (accessToken == null || accessToken.isEmpty || mapboxId.isEmpty) {
      return null;
    }

    final uri = Uri.https(
      'api.mapbox.com',
      '/search/searchbox/v1/retrieve/$mapboxId',
      <String, String>{
        'access_token': accessToken,
        'session_token': sessionToken,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final features = decoded['features'] as List<dynamic>? ?? const [];
    if (features.isEmpty) return null;

    final feature = features.first as Map<String, dynamic>;
    final properties =
        (feature['properties'] as Map<String, dynamic>? ?? const {});
    final geometry =
        (feature['geometry'] as Map<String, dynamic>? ?? const {});
    final coords = geometry['coordinates'] as List<dynamic>? ?? const [];

    final lng = coords.isNotEmpty ? (coords[0] as num).toDouble() : 0.0;
    final lat = coords.length > 1 ? (coords[1] as num).toDouble() : 0.0;
    final name = properties['name']?.toString() ?? mapboxId;
    final placeFormatted = properties['place_formatted']?.toString();
    final featureType = properties['feature_type']?.toString();

    return LocationModel(
      locationId: -mapboxId.hashCode.abs(),
      name: name,
      vicinity: placeFormatted,
      lat: lat,
      lng: lng,
      createdAt: DateTime.now(),
      googlePlaceId: mapboxId,
      types: featureType,
    );
  }

  MapboxSuggestion? _parseSuggestion(Map<String, dynamic> json) {
    final mapboxId = json['mapbox_id']?.toString();
    final name = json['name']?.toString();
    if (mapboxId == null || mapboxId.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    final distance = json['distance'];
    return MapboxSuggestion(
      mapboxId: mapboxId,
      name: name,
      placeFormatted: json['place_formatted']?.toString(),
      featureType: json['feature_type']?.toString(),
      address: json['address']?.toString(),
      distanceMeters: distance is num ? distance.toDouble() : null,
      poiCategory: (json['poi_category'] as List<dynamic>?)
          ?.map((value) => value.toString())
          .join(', '),
    );
  }

  static final Random _random = Random.secure();

  /// Generates a UUIDv4-formatted string suitable for use as a Mapbox
  /// Search Box session token. Avoids pulling in the `uuid` package.
  static String newSessionToken() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-'
        '${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-'
        '${h.substring(20, 32)}';
  }
}
