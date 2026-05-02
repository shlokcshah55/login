import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/recommendations_api.dart';

void main() {
  test('recommendations api base url defaults to production', () {
    expect(
      resolveRecommendationsApiBaseUrl(env: const {}),
      RecommendationsApi.defaultBaseUrl,
    );
  });

  test('recommendations api base url can use local magic search override', () {
    expect(
      resolveRecommendationsApiBaseUrl(
        env: const {'MAGIC_SEARCH_API_URL': 'http://localhost:8080'},
      ),
      'http://localhost:8080',
    );
  });

  test('recommendations api strips magic search route from override', () {
    expect(
      resolveRecommendationsApiBaseUrl(
        env: const {
          'MAGIC_SEARCH_API_URL':
              'http://localhost:8080/locations/magic-search',
        },
      ),
      'http://localhost:8080',
    );
  });
}
