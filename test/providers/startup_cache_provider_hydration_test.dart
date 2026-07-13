import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/users.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:mocktail/mocktail.dart';

class _MockGooglePlacesService extends Mock implements GooglePlacesService {}

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput: 'GOOGLE_PLACE_API_KEY=test\nAPI_SECRET_KEY=test\n',
    );
  });

  test('user provider publishes cached profile without a remote fetch', () {
    final provider = UserDataProvider();
    final profile = UserModel(
      supabaseId: 'user-1',
      email: 'cached@example.com',
      name: 'Cached User',
    );

    provider.hydrateCachedProfile('user-1', profile);

    expect(provider.userId, 'user-1');
    expect(provider.supabaseUserData, same(profile));
    expect(provider.userData?['name'], 'Cached User');
    expect(provider.isLoading, isFalse);
    expect(provider.isStale, isTrue);
  });

  test('clearing user data resets cached stale state', () async {
    final provider = UserDataProvider();
    provider.hydrateCachedProfile(
      'user-1',
      UserModel(
        supabaseId: 'user-1',
        email: 'cached@example.com',
      ),
    );

    await provider.clearUserData();

    expect(provider.supabaseUserData, isNull);
    expect(provider.isStale, isFalse);
  });

  test('cached locations are usable before marker rebuilding completes',
      () async {
    final markerCompleter = Completer<MapMarkerData?>();
    final manager = LocationListManager(
      _MockGooglePlacesService(),
      startBackgroundUserServices: false,
      savedMarkerBuilder: (_, __) => markerCompleter.future,
    );
    manager.setUserId('user-1', fetchSavedLocations: false);

    manager.hydrateCachedSavedLocations(<LocationModel>[
      LocationModel(
        locationId: 7,
        name: 'Cached Place',
        createdAt: DateTime.utc(2026, 7, 1),
        lat: 51.5,
        lng: -0.1,
      ),
    ]);

    expect(manager.hasLoadedSavedLocations, isTrue);
    expect(manager.isSavedDataStale, isTrue);
    expect(manager.isRebuildingCachedMarkers, isTrue);
    expect(manager.savedLocations.keys.single.locationId, 7);
    expect(
      manager.savedLocations.values.single.position,
      const LatLng(51.5, -0.1),
    );

    markerCompleter.complete(const MapMarkerData(
      id: '7',
      position: LatLng(51.5, -0.1),
      imageBytes: <int>[1, 2, 3],
    ));
    await pumpEventQueue();

    expect(manager.isRebuildingCachedMarkers, isFalse);
    expect(manager.savedLocations.values.single.imageBytes, <int>[1, 2, 3]);
  });

  test('clearing location data resets cached stale state', () {
    final manager = LocationListManager(
      _MockGooglePlacesService(),
      startBackgroundUserServices: false,
      savedMarkerBuilder: (location, _) async => MapMarkerData(
        id: location.locationId.toString(),
        position: LatLng(location.lat ?? 0, location.lng ?? 0),
        imageBytes: const <int>[],
      ),
    );
    manager.setUserId('user-1', fetchSavedLocations: false);
    manager.hydrateCachedSavedLocations(<LocationModel>[
      LocationModel(
        locationId: 7,
        name: 'Cached Place',
        createdAt: DateTime.utc(2026, 7, 1),
      ),
    ]);

    manager.clearData();

    expect(manager.hasLoadedSavedLocations, isFalse);
    expect(manager.isSavedDataStale, isFalse);
  });

  test('forced refresh replaces cached locations and clears stale state',
      () async {
    final manager = LocationListManager(
      _MockGooglePlacesService(),
      startBackgroundUserServices: false,
      savedLocationsLoader: () async => <LocationModel>[
        LocationModel(
          locationId: 8,
          name: 'Fresh Place',
          createdAt: DateTime.utc(2026, 7, 13),
        ),
      ],
      savedMarkerBuilder: (location, _) async => MapMarkerData(
        id: location.locationId.toString(),
        position: LatLng(location.lat ?? 0, location.lng ?? 0),
        imageBytes: const <int>[],
      ),
    );
    manager.setUserId('user-1', fetchSavedLocations: false);
    manager.hydrateCachedSavedLocations(<LocationModel>[
      LocationModel(
        locationId: 7,
        name: 'Cached Place',
        createdAt: DateTime.utc(2026, 7, 1),
      ),
    ]);

    await manager.fetchSavedLocations(force: true);

    expect(manager.hasLoadedSavedLocations, isTrue);
    expect(manager.savedLocations.keys.single.locationId, 8);
    expect(manager.isSavedDataStale, isFalse);
  });
}
