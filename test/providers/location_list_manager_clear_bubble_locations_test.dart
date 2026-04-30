import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/services/recommendations_api.dart';
import 'package:login/utils/geo_types.dart';
import 'package:mocktail/mocktail.dart';

class _MockGooglePlacesService extends Mock implements GooglePlacesService {}

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput: 'GOOGLE_PLACE_API_KEY=test\nAPI_SECRET_KEY=test\n',
    );
  });

  test('clearBubbleLocations clears bubbleLocations and currentItems',
      () async {
    final manager = LocationListManager(_MockGooglePlacesService());

    await manager.setCurrentListType(LocationListType.bubble);

    final location = LocationModel(
      locationId: 1,
      name: 'Test Location',
      createdAt: DateTime(2026, 1, 1),
    );
    manager.bubbleLocations[location] = const MapMarkerData(
      id: '1',
      position: LatLng(0, 0),
      imageBytes: [],
    );

    expect(manager.bubbleLocations, isNotEmpty);
    expect(manager.currentItems, isNotEmpty);

    manager.clearBubbleLocations(notify: false);

    expect(manager.bubbleLocations, isEmpty);
    expect(manager.currentItems, isEmpty);
  });

  test('bubble search this area uses search-area loading and bubble endpoint',
      () async {
    final requestSeen = Completer<Map<String, dynamic>>();
    final response = Completer<http.Response>();
    final client = MockClient((request) {
      expect(request.url.path, '/recommendations/bubble');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requestSeen.complete(body);
      return response.future;
    });
    final manager = LocationListManager(
      _MockGooglePlacesService(),
      recommendationsApi: RecommendationsApi(client: client),
    );

    await manager.setCurrentListType(LocationListType.bubble);

    final search = manager.searchBubbleArea(
      memberIds: const ['user-1', 'user-2'],
      bubbleId: 'bubble-1',
      center: const LatLng(51.5, -0.12),
      radiusKm: 1.25,
    );
    final body = await requestSeen.future;

    expect(manager.isSearchingArea, isTrue);
    expect(manager.isLoadingRecommendations, isTrue);
    expect(body['user_ids'], ['user-1', 'user-2']);
    expect(body['bubble_id'], 'bubble-1');
    expect(body['latitude'], 51.5);
    expect(body['longitude'], -0.12);
    expect(body['radius_km'], 1.25);

    response.complete(http.Response(
      jsonEncode({
        'user_id': '',
        'center_lat': 51.5,
        'center_lon': -0.12,
        'radius_km': 1.25,
        'total_results': 0,
        'recommendations': [],
        'timestamp': '2026-04-30T00:00:00Z',
      }),
      200,
    ));

    expect(await search, isTrue);
    expect(manager.isSearchingArea, isFalse);
    expect(manager.isLoadingRecommendations, isFalse);
    expect(manager.currentListType, LocationListType.bubble);
    expect(manager.error, LocationListManager.noRecommendationsInAreaMessage);
  });
}
