import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/users.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/services/startup_cache/startup_cache_coordinator.dart';
import 'package:login/services/startup_cache/startup_snapshot.dart';
import 'package:login/services/startup_cache/startup_snapshot_store.dart';
import 'package:login/utils/geo_types.dart';
import 'package:mocktail/mocktail.dart';

class _MockGooglePlacesService extends Mock implements GooglePlacesService {}

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput: 'GOOGLE_PLACE_API_KEY=test\nAPI_SECRET_KEY=test\n',
    );
  });

  test('hydrates matching cached sections and current consent', () async {
    final store = _FakeStartupSnapshotStore(
      _hit(_snapshot(userId: 'user-1')),
    );
    final coordinator = StartupCacheCoordinator(
      store: store,
      requiredConsentVersion: 'v1',
      writeDebounce: Duration.zero,
    );
    final userProvider = UserDataProvider();
    final locationManager = _locationManager()
      ..setUserId(
        'user-1',
        fetchSavedLocations: false,
      );

    final result = await coordinator.hydrate(
      userId: 'user-1',
      userDataProvider: userProvider,
      locationListManager: locationManager,
    );

    expect(result.profileHydrated, isTrue);
    expect(result.savedLocationsHydrated, isTrue);
    expect(result.hasCurrentConsent, isTrue);
    expect(result.hasUsableHomeData, isTrue);
    expect(userProvider.supabaseUserData?.name, 'Cached User');
    expect(locationManager.savedLocations.keys.single.locationId, 7);
    expect(coordinator.lastReadResult?.status, StartupSnapshotReadStatus.hit);
  });

  test('partial snapshot hydrates valid locations without a profile', () async {
    final store = _FakeStartupSnapshotStore(
      _hit(_snapshot(userId: 'user-1', includeProfile: false)),
    );
    final coordinator = StartupCacheCoordinator(store: store);
    final userProvider = UserDataProvider();
    final locationManager = _locationManager()
      ..setUserId(
        'user-1',
        fetchSavedLocations: false,
      );

    final result = await coordinator.hydrate(
      userId: 'user-1',
      userDataProvider: userProvider,
      locationListManager: locationManager,
    );

    expect(result.profileHydrated, isFalse);
    expect(result.savedLocationsHydrated, isTrue);
    expect(userProvider.supabaseUserData, isNull);
    expect(locationManager.hasLoadedSavedLocations, isTrue);
  });

  test('disabled coordinator does not read or write snapshots', () async {
    final store = _FakeStartupSnapshotStore(
      _hit(_snapshot(userId: 'user-1')),
    );
    final coordinator = StartupCacheCoordinator(
      store: store,
      enabled: false,
      writeDebounce: Duration.zero,
    );

    final result = await coordinator.hydrate(
      userId: 'user-1',
      userDataProvider: UserDataProvider(),
      locationListManager: _locationManager(),
    );
    coordinator.scheduleWrite(
      userId: 'user-1',
      profile: _profile('user-1'),
      savedLocations: _locations(),
    );
    await pumpEventQueue();

    expect(result.hasUsableHomeData, isFalse);
    expect(store.readCalls, 0);
    expect(store.writes, isEmpty);
  });

  test('a user switch discards an older outstanding cache read', () async {
    final store = _CompletingStartupSnapshotStore();
    final coordinator = StartupCacheCoordinator(store: store);
    final oldUserProvider = UserDataProvider();
    final oldLocations = _locationManager()
      ..setUserId(
        'user-1',
        fetchSavedLocations: false,
      );

    final oldHydration = coordinator.hydrate(
      userId: 'user-1',
      userDataProvider: oldUserProvider,
      locationListManager: oldLocations,
    );
    final newHydration = coordinator.hydrate(
      userId: 'user-2',
      userDataProvider: UserDataProvider(),
      locationListManager: _locationManager(),
    );
    store.complete(
        'user-2',
        const StartupSnapshotReadResult(
          status: StartupSnapshotReadStatus.miss,
        ));
    await newHydration;
    store.complete('user-1', _hit(_snapshot(userId: 'user-1')));

    final oldResult = await oldHydration;

    expect(oldResult.profileHydrated, isFalse);
    expect(oldUserProvider.supabaseUserData, isNull);
    expect(oldLocations.hasLoadedSavedLocations, isFalse);
  });

  test('writes are debounced and identical state is not rewritten', () async {
    final store = _FakeStartupSnapshotStore(
      const StartupSnapshotReadResult(status: StartupSnapshotReadStatus.miss),
    );
    final coordinator = StartupCacheCoordinator(
      store: store,
      writeDebounce: Duration.zero,
      now: () => DateTime.utc(2026, 7, 13),
    );
    await coordinator.hydrate(
      userId: 'user-1',
      userDataProvider: UserDataProvider(),
      locationListManager: _locationManager(),
    );

    coordinator.scheduleWrite(
      userId: 'user-1',
      profile: _profile('user-1'),
      savedLocations: _locations(),
    );
    coordinator.scheduleWrite(
      userId: 'user-1',
      profile: _profile('user-1'),
      savedLocations: _locations(),
    );
    await pumpEventQueue();
    coordinator.scheduleWrite(
      userId: 'user-1',
      profile: _profile('user-1'),
      savedLocations: _locations(),
    );
    await pumpEventQueue();

    expect(store.writes, hasLength(1));
  });

  test('marking consent accepted persists the current policy version',
      () async {
    final store = _FakeStartupSnapshotStore(
      const StartupSnapshotReadResult(status: StartupSnapshotReadStatus.miss),
    );
    final coordinator = StartupCacheCoordinator(
      store: store,
      requiredConsentVersion: 'v1',
      writeDebounce: Duration.zero,
    );
    await coordinator.hydrate(
      userId: 'user-1',
      userDataProvider: UserDataProvider(),
      locationListManager: _locationManager(),
    );

    coordinator.markConsentAccepted(
      userId: 'user-1',
      profile: _profile('user-1'),
      savedLocations: _locations(),
    );
    await pumpEventQueue();

    expect(store.writes.single.acceptedConsentVersion, 'v1');
  });

  test('clearing consent acceptance removes the cached policy version',
      () async {
    final store = _FakeStartupSnapshotStore(
      _hit(_snapshot(userId: 'user-1')),
    );
    final coordinator = StartupCacheCoordinator(
      store: store,
      requiredConsentVersion: 'v1',
      writeDebounce: Duration.zero,
    );
    final userProvider = UserDataProvider();
    final locationManager = _locationManager();
    await coordinator.hydrate(
      userId: 'user-1',
      userDataProvider: userProvider,
      locationListManager: locationManager,
    );

    coordinator.clearConsentAcceptance(
      userId: 'user-1',
      profile: userProvider.supabaseUserData,
      savedLocations: locationManager.savedLocations.keys.toList(),
    );
    await pumpEventQueue();

    expect(store.writes.single.acceptedConsentVersion, isNull);
  });

  test('refresh status exposes stale cached data only after failure', () async {
    final coordinator = StartupCacheCoordinator(
      store: _FakeStartupSnapshotStore(_hit(_snapshot(userId: 'user-1'))),
    );
    await coordinator.hydrate(
      userId: 'user-1',
      userDataProvider: UserDataProvider(),
      locationListManager: _locationManager(),
    );
    final statuses = <StartupCacheRefreshStatus>[];
    coordinator.addListener(() => statuses.add(coordinator.refreshStatus));

    coordinator.markRefreshStarted();
    coordinator.markRefreshCompleted(hadFailure: true);

    expect(statuses, <StartupCacheRefreshStatus>[
      StartupCacheRefreshStatus.refreshing,
      StartupCacheRefreshStatus.stale,
    ]);
  });

  test('clearActiveUser removes the active snapshot', () async {
    final store = _FakeStartupSnapshotStore(
      _hit(_snapshot(userId: 'user-1')),
    );
    final coordinator = StartupCacheCoordinator(store: store);
    await coordinator.hydrate(
      userId: 'user-1',
      userDataProvider: UserDataProvider(),
      locationListManager: _locationManager(),
    );

    await coordinator.clearActiveUser();

    expect(store.clearedUsers, <String>['user-1']);
    expect(coordinator.activeUserId, isNull);
  });
}

LocationListManager _locationManager() {
  return LocationListManager(
    _MockGooglePlacesService(),
    startBackgroundUserServices: false,
    savedMarkerBuilder: (location, _) async => MapMarkerData(
      id: location.locationId.toString(),
      position: LatLng(location.lat ?? 0, location.lng ?? 0),
      imageBytes: const <int>[],
    ),
  );
}

StartupSnapshot _snapshot({
  required String userId,
  bool includeProfile = true,
}) {
  return StartupSnapshot(
    schemaVersion: StartupSnapshot.currentSchemaVersion,
    userId: userId,
    writtenAt: DateTime.utc(2026, 7, 13),
    profile: includeProfile ? _profile(userId) : null,
    savedLocations: _locations(),
    acceptedConsentVersion: 'v1',
  );
}

UserModel _profile(String userId) => UserModel(
      supabaseId: userId,
      email: '$userId@example.com',
      name: 'Cached User',
    );

List<LocationModel> _locations() => <LocationModel>[
      LocationModel(
        locationId: 7,
        name: 'Cached Place',
        createdAt: DateTime.utc(2026, 7, 1),
        lat: 51.5,
        lng: -0.1,
      ),
    ];

StartupSnapshotReadResult _hit(StartupSnapshot snapshot) {
  return StartupSnapshotReadResult(
    status: StartupSnapshotReadStatus.hit,
    snapshot: snapshot,
    byteSize: 100,
  );
}

class _FakeStartupSnapshotStore implements StartupSnapshotStore {
  _FakeStartupSnapshotStore(this.readResult);

  StartupSnapshotReadResult readResult;
  int readCalls = 0;
  final List<StartupSnapshot> writes = <StartupSnapshot>[];
  final List<String> clearedUsers = <String>[];

  @override
  Future<StartupSnapshotReadResult> read(String userId) async {
    readCalls += 1;
    return readResult;
  }

  @override
  Future<void> write(StartupSnapshot snapshot) async {
    writes.add(snapshot);
  }

  @override
  Future<void> clear(String userId) async {
    clearedUsers.add(userId);
  }

  @override
  Future<void> clearAll() async {}
}

class _CompletingStartupSnapshotStore implements StartupSnapshotStore {
  final Map<String, Completer<StartupSnapshotReadResult>> _reads =
      <String, Completer<StartupSnapshotReadResult>>{};

  void complete(String userId, StartupSnapshotReadResult result) {
    _reads[userId]!.complete(result);
  }

  @override
  Future<StartupSnapshotReadResult> read(String userId) {
    return (_reads[userId] ??= Completer<StartupSnapshotReadResult>()).future;
  }

  @override
  Future<void> write(StartupSnapshot snapshot) async {}

  @override
  Future<void> clear(String userId) async {}

  @override
  Future<void> clearAll() async {}
}
