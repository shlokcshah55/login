import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:mocktail/mocktail.dart';

class _MockGooglePlacesService extends Mock implements GooglePlacesService {}

LocationListManager _managerWithSaved(List<LocationModel> saved) {
  final manager = LocationListManager(
    _MockGooglePlacesService(),
    startBackgroundUserServices: false,
    savedMarkerBuilder: (location, _) async => MapMarkerData(
      id: location.locationId.toString(),
      position: LatLng(location.lat!, location.lng!),
      imageBytes: const <int>[],
    ),
  );
  manager.hydrateCachedSavedLocations(saved);
  return manager;
}

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput: 'GOOGLE_PLACE_API_KEY=test\nAPI_SECRET_KEY=test\n',
    );
  });

  test('in GeoJSON mode a list switch publishes immediately without PNGs',
      () async {
    final manager = _managerWithSaved([_location(1), _location(2)])
      ..attachMapStateProvider(MapStateProvider());
    await pumpEventQueue();
    await manager.setCurrentListType(LocationListType.recommended);

    var notifications = 0;
    List<int>? idsAtFirstNotify;
    manager.addListener(() {
      notifications++;
      idsAtFirstNotify ??=
          manager.currentItems.keys.map((l) => l.locationId).toList();
    });

    final switching = manager.setCurrentListType(LocationListType.saved);
    // Published synchronously, before any await.
    expect(idsAtFirstNotify, [1, 2]);
    await switching;

    expect(notifications, 1);
    expect(
      manager.currentItems.values.every((m) => m.imageBytes.isEmpty),
      isTrue,
    );
  });

  test('rapid list switches always land on the last one', () async {
    final manager = _managerWithSaved([_location(1), _location(2)])
      ..attachMapStateProvider(MapStateProvider());
    await pumpEventQueue();

    await Future.wait([
      manager.setCurrentListType(LocationListType.recommended),
      manager.setCurrentListType(LocationListType.saved),
      manager.setCurrentListType(LocationListType.recommended),
    ]);

    expect(manager.currentListType, LocationListType.recommended);
    expect(manager.currentItems, isEmpty);
  });
}

LocationModel _location(int id) => LocationModel(
      locationId: id,
      name: 'Place $id',
      lat: 51.5,
      lng: -0.12 + id * 0.001,
      createdAt: DateTime(2026, 5, 1),
    );
