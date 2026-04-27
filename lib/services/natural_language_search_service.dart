import 'dart:convert';

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
    String endpoint = defaultEndpoint,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _client = client ?? http.Client(),
        _endpoint = endpoint;

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
    final locationIds = recommendations
        .map((item) => (item as Map<String, dynamic>)['location_id'])
        .where((id) => id != null)
        .map((id) => (id as num).toInt())
        .toList();

    if (locationIds.isEmpty) {
      return const [];
    }

    final responseRows = await Supabase.instance.client
        .from(SupabaseConstants.tableLocations)
        .select()
        .inFilter(SupabaseConstants.columnLocationId, locationIds);

    final processed = await _supabaseService.locations.processLocationsWithImages(
      responseRows as List,
    );
    final byId = <int, LocationModel>{
      for (final location in processed) location.locationId: location,
    };

    return locationIds
        .map((id) => byId[id])
        .whereType<LocationModel>()
        .toList();
  }
}
