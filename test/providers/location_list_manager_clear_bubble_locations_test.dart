import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/utils/geo_types.dart';

void main() {
  test('clearBubbleLocations clears bubbleLocations and currentItems', () async {
    final manager = LocationListManager(GooglePlacesService());

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
}

