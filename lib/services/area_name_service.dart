import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Resolves a short area name ("Islington", "Soho") for a coordinate via
/// Mapbox reverse geocoding (neighbourhood, then locality).
///
/// Results are cached per ~110 m cell (lat/lng rounded to 3 dp), so panning
/// around one area never repeats the request. In-flight lookups for the same
/// cell are shared.
class AreaNameService {
  AreaNameService({http.Client? client, String? accessToken})
      : _client = client ?? http.Client(),
        _accessToken = accessToken ?? dotenv.env['MAPBOX_ACCESS_TOKEN'];

  static final AreaNameService instance = AreaNameService();

  final http.Client _client;
  final String? _accessToken;
  final Map<String, String?> _cache = {};
  final Map<String, Future<String?>> _inFlight = {};

  static const int _maxCacheEntries = 200;

  @visibleForTesting
  static String cellKey(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';

  /// Cached name for the cell, without a network call. Null when unknown.
  String? cached(double latitude, double longitude) =>
      _cache[cellKey(latitude, longitude)];

  Future<String?> lookup(double latitude, double longitude) {
    final key = cellKey(latitude, longitude);
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    return _inFlight[key] ??= _fetch(latitude, longitude).then((name) {
      _inFlight.remove(key);
      if (_cache.length >= _maxCacheEntries) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = name;
      return name;
    });
  }

  Future<String?> _fetch(double latitude, double longitude) async {
    final token = _accessToken;
    if (token == null || token.isEmpty) return null;
    final uri = Uri.https('api.mapbox.com', '/search/geocode/v6/reverse', {
      'longitude': longitude.toStringAsFixed(5),
      'latitude': latitude.toStringAsFixed(5),
      'types': 'neighborhood,locality',
      'language': 'en',
      'access_token': token,
    });
    try {
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      return parseAreaName(jsonDecode(response.body));
    } catch (e) {
      debugPrint('[AreaNameService] reverse geocode failed: $e');
      return null;
    }
  }

  /// Prefers a neighbourhood over a locality when both are returned.
  @visibleForTesting
  static String? parseAreaName(Object? body) {
    if (body is! Map) return null;
    final features = body['features'];
    if (features is! List) return null;
    String? locality;
    for (final feature in features) {
      if (feature is! Map) continue;
      final props = feature['properties'];
      if (props is! Map) continue;
      final name = (props['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final type = props['feature_type'];
      if (type == 'neighborhood') return name;
      if (type == 'locality') locality ??= name;
    }
    return locality;
  }
}
