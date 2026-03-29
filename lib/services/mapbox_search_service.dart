import 'dart:convert';
import 'dart:math' hide log;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/models/mapbox_search_models.dart';
import 'dart:developer';

class MapboxSearchService {
  final String _baseUrl = 'https://api.mapbox.com/search/searchbox/v1';
  late String _sessionToken;
  final http.Client _client;

  MapboxSearchService({http.Client? client}) : _client = client ?? http.Client() {
    _generateNewSessionToken();
  }

  void _generateNewSessionToken() {
    final random = Random.secure();
    _sessionToken = List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  String? get _accessToken => dotenv.env['MAPBOX_ACCESS_TOKEN'];

  Future<List<MapboxSuggestion>> getSuggestions(String query, {
    double? proximityLat,
    double? proximityLng,
  }) async {
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('MAPBOX_ACCESS_TOKEN not found in .env');
    }

    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse('$_baseUrl/suggest').replace(queryParameters: {
        'q': query,
        'access_token': _accessToken,
        'session_token': _sessionToken,
        if (proximityLat != null && proximityLng != null)
          'proximity': '$proximityLng,$proximityLat',
        // 'types': 'place,address,neighborhood,poi' // Optional, restrict types
      });

      log('MapboxSearchService: Fetching suggestions for: $query');
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestions = data['suggestions'] as List<dynamic>?;
        
        if (suggestions == null) return [];

        return suggestions.map((s) => MapboxSuggestion.fromJson(s)).toList();
      } else {
        log('MapboxSearchService: Error fetching suggestions: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      log('MapboxSearchService: Exception fetching suggestions: $e');
      return [];
    }
  }

  Future<MapboxPlaceDetails?> retrievePlace(String mapboxId) async {
    if (_accessToken == null || _accessToken!.isEmpty) {
      throw Exception('MAPBOX_ACCESS_TOKEN not found in .env');
    }

    try {
      final uri = Uri.parse('$_baseUrl/retrieve/$mapboxId').replace(queryParameters: {
        'access_token': _accessToken,
        'session_token': _sessionToken,
      });

      log('MapboxSearchService: Retrieving place for ID: $mapboxId');
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>?;
        
        if (features != null && features.isNotEmpty) {
          // After a retrieve, the session token must be regenerated according to Mapbox docs
          _generateNewSessionToken();
          return MapboxPlaceDetails.fromJson(features.first);
        }
      } else {
        log('MapboxSearchService: Error retrieving place: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      log('MapboxSearchService: Exception retrieving place: $e');
    }
    return null;
  }
}
