import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:login/models/proximal_models.dart';

class RecommendationsApi {
  static const String _baseUrl =
      'https://pinit-recommendations-api-lxtqmosyka-nw.a.run.app';
  static const String _path = '/recommendations/proximal';

  final http.Client _client;

  RecommendationsApi({http.Client? client}) : _client = client ?? http.Client();

  Future<ProximalResponse> fetchProximal({
    required String userId,
    required double latitude,
    required double longitude,
    required double radiusKm,
    int maxResults = 20,
    double tasteWeight = 0.2,
    double proximityWeight = 0.6,
    double qualityWeight = 0.2,
    bool includeTasteBreakdown = false,
    List<String>? vibeTagIds,
    List<String>? cuisineTagIds,
  }) async {
    // Log request parameters
    log('🔍 [RecommendationsApi] fetchProximal called with parameters:');
    log('   userId: $userId');
    log('   latitude: $latitude, longitude: $longitude');
    log('   radiusKm: $radiusKm, maxResults: $maxResults');
    log('   tasteWeight: $tasteWeight, proximityWeight: $proximityWeight, qualityWeight: $qualityWeight');
    log('   vibeTagIds: ${vibeTagIds ?? "null"} (count: ${vibeTagIds?.length ?? 0})');
    log('   cuisineTagIds: ${cuisineTagIds ?? "null"} (count: ${cuisineTagIds?.length ?? 0})');
    log('   includeTasteBreakdown: $includeTasteBreakdown');

    final request = ProximalRequest(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      maxResults: maxResults,
      tasteWeight: tasteWeight,
      proximityWeight: proximityWeight,
      qualityWeight: qualityWeight,
      includeTasteBreakdown: includeTasteBreakdown,
      vibeTagIds: vibeTagIds,
      cuisineTagIds: cuisineTagIds,
    );

    final requestJson = request.toJson();
    final uri = Uri.parse('$_baseUrl$_path');

    // Log the full request body
    log('📤 [RecommendationsApi] POST request to: $uri');
    log('📤 [RecommendationsApi] Request body: ${jsonEncode(requestJson)}');

    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestJson),
    );

    log('📥 [RecommendationsApi] Response status: ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      log('❌ [RecommendationsApi] Request failed: ${response.body}');
      throw RecommendationsApiException(
        'Failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final proximalResponse = ProximalResponse.fromJson(decoded);

    log('✅ [RecommendationsApi] Success! Received ${proximalResponse.recommendations.length} recommendations');

    return proximalResponse;
  }

  Future<ProximalResponse> fetchProximalBubble({
    required List<String> userIds,
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int maxResults = 20,
    double tasteWeight = 0.3,
    double proximityWeight = 0.5,
    double qualityWeight = 0.2,
  }) async {
    final requestBody = {
      'user_ids': userIds,
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
      'max_results': maxResults,
      'taste_weight': tasteWeight,
      'proximity_weight': proximityWeight,
      'quality_weight': qualityWeight,
    };

    final uri = Uri.parse('$_baseUrl/recommendations/bubble');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RecommendationsApiException(
        'Failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ProximalResponse.fromJson(decoded);
  }
}

class RecommendationsApiException implements Exception {
  final String message;

  RecommendationsApiException(this.message);

  @override
  String toString() => message;
}
