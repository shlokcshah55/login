import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:login/models/proximal_models.dart';

class RecommendationsApi {
  static const String _baseUrl =
      'https://pinit-recommendations-api-630839392908.europe-west2.run.app';
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
  }) async {
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
    );

    final uri = Uri.parse('$_baseUrl$_path');
    final response = await _client.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
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
