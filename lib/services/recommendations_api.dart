import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:login/models/proximal_models.dart';

class RecommendationsApi {
  static const int defaultMaxResults = 30;
  static const String _baseUrl =
      'https://pinit-recommendations-api-jkqbw4i75a-nw.a.run.app';
  static const String _path = '/recommendations/proximal';
  static const String _addLocationPath = '/locations/add';

  final http.Client _client;

  RecommendationsApi({http.Client? client}) : _client = client ?? http.Client();

  Future<ProximalResponse> fetchProximal({
    required String userId,
    required double latitude,
    required double longitude,
    required double radiusKm,
    int maxResults = defaultMaxResults,
    double qualityWeight = 0.30,
    double vibeWeight = 0.25,
    double dietaryWeight = 0.10,
    double socialWeight = 0.20,
    double collaborativeWeight = 0.15,
    bool includeTasteBreakdown = false,
    List<String>? cuisines,
    Map<String, dynamic>? filters,
  }) async {
    final effectiveMaxResults = maxResults < 1
        ? 1
        : (maxResults > defaultMaxResults ? defaultMaxResults : maxResults);

    // Build filters map — merge cuisines shortcut into explicit filters.
    final mergedFilters = <String, dynamic>{
      if (filters != null) ...filters,
      if (cuisines != null && cuisines.isNotEmpty) 'cuisine': cuisines,
    };

    // Log request parameters
    print('🔍 [RecommendationsApi] fetchProximal called with parameters:');
    print('   userId: $userId');
    print('   latitude: $latitude, longitude: $longitude');
    print('   radiusKm: $radiusKm, maxResults: $effectiveMaxResults');
    print('   weights — quality: $qualityWeight, vibe: $vibeWeight, dietary: $dietaryWeight, social: $socialWeight, collaborative: $collaborativeWeight');
    print('   filters: ${mergedFilters.isEmpty ? "(none)" : mergedFilters}');
    print('   includeTasteBreakdown: $includeTasteBreakdown');

    final request = ProximalRequest(
      userId: userId,
      latitude: latitude,
      longitude: longitude,
      radiusKm: 8,
      maxResults: effectiveMaxResults,
      qualityWeight: qualityWeight,
      vibeWeight: vibeWeight,
      dietaryWeight: dietaryWeight,
      socialWeight: socialWeight,
      collaborativeWeight: collaborativeWeight,
      includeTasteBreakdown: includeTasteBreakdown,
      filters: mergedFilters.isEmpty ? null : mergedFilters,
    );

    final requestJson = request.toJson();
    final uri = Uri.parse('$_baseUrl$_path');

    // Log the full request body
    print('📤 [RecommendationsApi] POST request to: $uri');
    print('📤 [RecommendationsApi] Request body: ${jsonEncode(requestJson)}');

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

        print('📥 [RecommendationsApi] Response status: ${response.statusCode}');

        // Success or client error - don't retry
        if (response.statusCode < 500) {
          break;
        }

        // 500+ error - retry if we haven't exhausted attempts
        if (attempt < maxRetries) {
          print('⚠️ [RecommendationsApi] Server error (${response.statusCode}), retrying in ${retryDelays[attempt].inMilliseconds}ms (attempt ${attempt + 1}/$maxRetries)');
          await Future.delayed(retryDelays[attempt]);
          continue;
        }
      } on TimeoutException {
        if (attempt < maxRetries) {
          print('⏱️ [RecommendationsApi] Request timeout, retrying (attempt ${attempt + 1}/$maxRetries)');
          await Future.delayed(retryDelays[attempt]);
          continue;
        }
        rethrow;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('❌ [RecommendationsApi] Request failed: ${response.body}');
      throw RecommendationsApiException(
        'Failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final proximalResponse = ProximalResponse.fromJson(decoded);

    print(
      '✅ [RecommendationsApi] Success! Received '
      '${proximalResponse.recommendations.length} recommendations '
      '(requested: $effectiveMaxResults, total_results: ${proximalResponse.totalResults})',
    );

    return proximalResponse;
  }

  Future<ProximalResponse> fetchProximalBubble({
    required List<String> userIds,
    String? bubbleId,
    required double latitude,
    required double longitude,
    double radiusKm = 2.0,
    int maxResults = 20,
    double vibeWeight = 0.34,
    double dietaryWeight = 0.33,
    double qualityWeight = 0.33,
    bool includeIndividualScores = false,
    bool includeVibeBreakdown = false,
    Map<String, dynamic>? filters,
  }) async {
    final requestBody = <String, dynamic>{
      'user_ids': userIds,
      if (bubbleId != null && bubbleId.isNotEmpty) 'bubble_id': bubbleId,
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
      'max_results': maxResults,
      'vibe_weight': vibeWeight,
      'dietary_weight': dietaryWeight,
      'quality_weight': qualityWeight,
      'include_individual_scores': includeIndividualScores,
      'include_vibe_breakdown': includeVibeBreakdown,
      if (filters != null && filters.isNotEmpty) 'filters': filters,
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
    String source = 'in-app',
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
        'source': source,
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
