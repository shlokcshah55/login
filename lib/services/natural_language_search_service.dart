import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:login/models/locations.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NaturalLanguageSearchService {
  static const String defaultEndpoint =
      'https://pinit-recommendations-api-jkqbw4i75a-nw.a.run.app/locations/magic-search';

  final SupabaseService _supabaseService;
  final http.Client _client;
  final String _endpoint;

  NaturalLanguageSearchService({
    SupabaseService? supabaseService,
    http.Client? client,
    String? endpoint,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _client = client ?? http.Client(),
        _endpoint = endpoint ?? resolveMagicSearchEndpoint();

  Future<List<LocationModel>> search({
    required String userId,
    required String query,
    required LatLng currentLocation,
    double radiusKm = 2.0,
    int maxResults = 20,
    bool includeTasteBreakdown = false,
  }) async {
    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
        'prompt': query.trim(),
        'radius_km': radiusKm,
        'max_results': maxResults,
        'include_taste_breakdown': includeTasteBreakdown,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Natural language search failed with ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final recommendations =
        decoded['recommendations'] as List<dynamic>? ?? const [];
    final recommendationMaps = recommendations
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    final fallbackLocations =
        magicSearchRecommendationsToLocationModels(recommendationMaps);
    final locationIds = persistedMagicSearchLocationIds(recommendationMaps);

    if (locationIds.isEmpty) {
      return fallbackLocations;
    }

    final responseRows = await Supabase.instance.client
        .from(SupabaseConstants.tableLocations)
        .select()
        .inFilter(SupabaseConstants.columnLocationId, locationIds);

    final processed =
        await _supabaseService.locations.processLocationsWithImages(
      responseRows as List,
    );
    final byId = <int, LocationModel>{
      for (final location in processed) location.locationId: location,
    };

    return fallbackLocations.map((location) {
      if (location.locationId > 0) {
        return byId[location.locationId] ?? location;
      }
      return location;
    }).toList(growable: false);
  }
}

String resolveMagicSearchEndpoint({Map<String, String>? env}) {
  final source = env ?? dotenv.env;
  final override = source['MAGIC_SEARCH_API_URL']?.trim();
  if (override == null || override.isEmpty) {
    return NaturalLanguageSearchService.defaultEndpoint;
  }

  final withoutTrailingSlash = override.replaceFirst(RegExp(r'/+$'), '');
  if (withoutTrailingSlash.endsWith('/locations/magic-search')) {
    return withoutTrailingSlash;
  }
  return '$withoutTrailingSlash/locations/magic-search';
}

List<int> persistedMagicSearchLocationIds(
  List<Map<String, dynamic>> recommendations,
) {
  final ids = <int>[];
  for (final recommendation in recommendations) {
    final raw = recommendation['location_id'];
    final id = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    if (id != null && id > 0) {
      ids.add(id);
    }
  }
  return ids;
}

List<LocationModel> magicSearchRecommendationsToLocationModels(
  List<Map<String, dynamic>> recommendations,
) {
  return recommendations
      .map(_magicSearchRecommendationToLocationModel)
      .whereType<LocationModel>()
      .toList(growable: false);
}

LocationModel? _magicSearchRecommendationToLocationModel(
  Map<String, dynamic> json,
) {
  final rawId = json['location_id'];
  final locationId =
      rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
  final googlePlaceId = json['google_place_id']?.toString().trim();
  final name = json['name']?.toString().trim();
  if (locationId == null || name == null || name.isEmpty) {
    return null;
  }

  return LocationModel(
    locationId: locationId,
    name: name,
    vicinity: _optionalString(json['vicinity']),
    lat: _optionalDouble(json['lat']),
    lng: _optionalDouble(json['lng']),
    createdAt: DateTime.now(),
    googlePlaceId:
        googlePlaceId == null || googlePlaceId.isEmpty ? null : googlePlaceId,
    rating: _optionalDouble(json['rating']),
    userRatingsTotal: _optionalInt(json['user_ratings_total']),
    priceLevel: _optionalInt(json['price_level']),
    cuisinePrimary: _optionalString(json['cuisine_primary']),
    types: _typesToString(json['types']),
    openNow: _optionalBool(json['open_now']),
    preference: LocationPreference.search,
  );
}

String? _optionalString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double? _optionalDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int? _optionalInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool? _optionalBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return null;
}

String? _typesToString(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).join(',');
  }
  return _optionalString(value);
}
