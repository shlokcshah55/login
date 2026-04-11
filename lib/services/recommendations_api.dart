import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:login/models/proximal_models.dart';

class RecommendationsApi {
  static const String _baseUrl =
      'https://pinit-recommendations-api-1070859807237.europe-west2.run.app';
  static const String _path = '/recommendations/proximal';
  static const String _addLocationPath = '/locations/add';

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

    // Retry logic for 500 errors (transient failures)
    const maxRetries = 3;
    const retryDelays = [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2)
    ];

    late http.Response response;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        response = await _client
            .post(
              uri,
              headers: const {
                'Content-Type': 'application/json',
              },
              body: jsonEncode(requestJson),
            )
            .timeout(const Duration(seconds: 30));

        log('📥 [RecommendationsApi] Response status: ${response.statusCode}');

        // Success or client error - don't retry
        if (response.statusCode < 500) {
          break;
        }

        // 500+ error - retry if we haven't exhausted attempts
        if (attempt < maxRetries) {
          log('⚠️ [RecommendationsApi] Server error (${response.statusCode}), retrying in ${retryDelays[attempt].inMilliseconds}ms (attempt ${attempt + 1}/$maxRetries)');
          await Future.delayed(retryDelays[attempt]);
          continue;
        }
      } on TimeoutException {
        if (attempt < maxRetries) {
          log('⏱️ [RecommendationsApi] Request timeout, retrying (attempt ${attempt + 1}/$maxRetries)');
          await Future.delayed(retryDelays[attempt]);
          continue;
        }
        rethrow;
      }
    }

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

  Future<int?> addLocationByGooglePlaceId({
    required String googlePlaceId,
    bool classifyPhoto = true,
  }) async {
    final trimmed = googlePlaceId.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.parse('$_baseUrl$_addLocationPath');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'google_place_id': trimmed,
        'classify_photo': classifyPhoto,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RecommendationsApiException(
        'Failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final locationId = decoded['location_id'];
    if (locationId is int) {
      return locationId;
    }
    if (locationId is num) {
      return locationId.toInt();
    }
    return null;
  }
}

class RecommendationsApiException implements Exception {
  final String message;

  RecommendationsApiException(this.message);

  @override
  String toString() => message;
}
