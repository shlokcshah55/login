import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/proximity/proximity_candidate.dart';
import 'package:login/services/proximity/proximity_data_source.dart';
import 'package:login/services/proximity/proximity_geofence_bridge.dart';
import 'package:login/services/proximity/proximity_regions.dart';
import 'package:login/services/proximity_notification_service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDataSource implements ProximityDataSource {
  Map<int, ProximityInsight> insights = {};
  final List<int> logged = [];

  @override
  Future<Map<int, ProximityInsight>> fetchInsights() async => insights;

  @override
  Future<List<({int locationId, DateTime sentAt})>> fetchRecentLog({
    Duration window = const Duration(days: 4),
  }) async =>
      const [];

  @override
  Future<void> logSent(int locationId) async => logged.add(locationId);
}

class _FakeBridge implements GeofenceBridge {
  final StreamController<GeofenceEvent> controller =
      StreamController<GeofenceEvent>.broadcast(sync: true);
  LocationAuthStatus status = LocationAuthStatus.always;
  bool postResult = true;
  bool ready = false;
  bool significantChanges = false;
  int clearCalls = 0;
  final List<List<GeofenceRegion>> registrations = [];
  final List<
          ({String id, String title, String body, Map<String, String> payload})>
      posted = [];

  @override
  bool get isSupported => true;

  @override
  Stream<GeofenceEvent> get events => controller.stream;

  @override
  Future<LocationAuthStatus> authorizationStatus() async => status;

  int alwaysRequests = 0;

  @override
  Future<void> requestAlwaysAuthorization() async => alwaysRequests++;

  @override
  Future<void> registerRegions(List<GeofenceRegion> regions) async =>
      registrations.add(regions);

  @override
  Future<void> clearRegions() async => clearCalls++;

  @override
  Future<void> setSignificantChangesEnabled(bool enabled) async =>
      significantChanges = enabled;

  @override
  Future<void> signalReady() async => ready = true;

  @override
  Future<bool> postNotification({
    required String id,
    required String title,
    required String body,
    required Map<String, String> payload,
  }) async {
    if (!postResult) return false;
    posted.add((id: id, title: title, body: body, payload: payload));
    return true;
  }
}

const _lat = 51.5;
const _lng = -0.1;
const _near = LatLng(_lat + 0.0009, _lng); // ~100 m

LocationModel _place(
  int id, {
  String? savedMethod,
  List<dynamic>? periods,
  bool? openNow,
  double lat = _lat,
}) =>
    LocationModel(
      locationId: id,
      name: 'Place $id',
      lat: lat,
      lng: _lng,
      createdAt: DateTime.utc(2025, 1, 1),
      savedMethod: savedMethod,
      openingHoursPeriods: periods,
      openNow: openNow,
    );

void main() {
  late _FakeDataSource data;
  late _FakeBridge bridge;
  late List<({String deepLink, Map<String, dynamic> payload})> taps;
  late DateTime now;
  late int presenterCalls;
  bool? presenterAnswer = true;
  late ProximityNotificationService service;

  ProximityNotificationService build() =>
      ProximityNotificationService.withDependencies(
        dataSource: data,
        sender: (userId, message) async => true,
        bridge: bridge,
        onNotificationTap: (deepLink, payload) async =>
            taps.add((deepLink: deepLink, payload: payload)),
        primingPresenter: () async {
          presenterCalls++;
          return presenterAnswer;
        },
        now: () => now,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    data = _FakeDataSource();
    bridge = _FakeBridge();
    taps = [];
    presenterCalls = 0;
    presenterAnswer = true;
    now = DateTime(2026, 10, 5, 12); // Monday midday
    service = build();
  });

  Future<void> start(List<LocationModel> places) async {
    await service.loadUserStateForTest('user-1');
    await service.startBackgroundMonitoringForTest();
    await service.syncSavedLocations(places);
  }

  group('registering regions', () {
    test('registers saved places once the user granted Always', () async {
      await start([_place(1), _place(2, lat: _lat + 0.01)]);

      expect(bridge.ready, isTrue);
      expect(bridge.significantChanges, isTrue);
      expect(
        service.registeredRegions.map((r) => r.id).toSet(),
        {'1', '2'},
      );
      expect(service.registeredRegions.first.radiusMeters, 400);
    });

    test('registers nothing without Always, keeping the stream fallback',
        () async {
      bridge.status = LocationAuthStatus.whenInUse;
      await start([_place(1)]);

      expect(bridge.registrations, isEmpty);
      expect(bridge.significantChanges, isFalse);
      expect(bridge.ready, isTrue);
    });

    test('does not re-register an unchanged set', () async {
      await start([_place(1)]);
      final before = bridge.registrations.length;

      await service.syncSavedLocations([_place(1)]);

      expect(bridge.registrations.length, before);
    });

    test('granting Always later registers; revoking it clears', () async {
      bridge.status = LocationAuthStatus.whenInUse;
      await start([_place(1)]);
      expect(bridge.registrations, isEmpty);

      bridge.controller.add(
        const AuthorizationChanged(LocationAuthStatus.always),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.registeredRegions.map((r) => r.id), ['1']);
      expect(bridge.significantChanges, isTrue);

      bridge.controller.add(
        const AuthorizationChanged(LocationAuthStatus.denied),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.registeredRegions, isEmpty);
      expect(bridge.clearCalls, 1);
      expect(bridge.significantChanges, isFalse);
    });

    test('a significant location change re-picks the nearest places', () async {
      // 20 places on a line; with a tight budget the nearest to the new
      // position must win.
      await start(
          [for (var i = 0; i < 40; i++) _place(i, lat: _lat + i * 0.01)]);
      expect(service.registeredRegions, hasLength(defaultMaxGeofenceRegions));

      bridge.controller.add(
        const SignificantLocationChange(LatLng(_lat + 0.39, _lng)),
      );
      await Future<void>.delayed(Duration.zero);

      final ids = service.registeredRegions.map((r) => int.parse(r.id)).toSet();
      expect(ids.contains(39), isTrue);
      expect(ids.contains(0), isFalse);
    });
  });

  group('entering a region', () {
    test('posts a local notification with creator-led copy', () async {
      data.insights = {
        1: const ProximityInsight(
          savedMethod: 'tiktok',
          creatorHandle: 'foodie',
          topDish: 'miso cod',
          confidenceTier: 'high',
        ),
      };
      await start([_place(1, savedMethod: 'tiktok')]);

      await service.handleGeofenceEnterForTest(1, at: _near);

      final note = bridge.posted.single;
      expect(note.id, 'proximity_1');
      expect(note.title, "@foodie's pick is nearby");
      expect(note.body, contains('miso cod'));
      expect(note.body, contains('100m'));
      expect(note.payload['deepLink'], 'pinit://location/1');
      expect(note.payload['type'], 'proximity_location');
      expect(data.logged, [1]);
    });

    test('without a position it reports the region radius as the distance',
        () async {
      await start([_place(1)]);

      await service.handleGeofenceEnterForTest(1);

      expect(bridge.posted.single.body, contains('400m'));
    });

    test('arrives through the event stream too', () async {
      await start([_place(1)]);

      bridge.controller.add(const GeofenceEntered(1));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bridge.posted, hasLength(1));
    });

    test('a second entry inside the cooldown is ignored', () async {
      await start([_place(1)]);

      await service.handleGeofenceEnterForTest(1);
      await service.handleGeofenceEnterForTest(1);

      expect(bridge.posted, hasLength(1));
    });

    test('and a cooled-down place frees its region slot', () async {
      await start([_place(1), _place(2, lat: _lat + 0.01)]);
      expect(service.registeredRegions, hasLength(2));

      await service.handleGeofenceEnterForTest(1);
      await Future<void>.delayed(Duration.zero);

      expect(service.registeredRegions.map((r) => r.id), ['2']);
    });

    test('quiet hours skip it, with no retry later', () async {
      await start([_place(1)]);

      now = DateTime(2026, 10, 5, 23);
      await service.handleGeofenceEnterForTest(1);
      expect(bridge.posted, isEmpty);

      now = DateTime(2026, 10, 6, 9);
      await service.handleGeofenceEnterForTest(1);
      // The OS only tells us about entries, so a later call is a new entry.
      expect(bridge.posted, hasLength(1));
    });

    test('closed places are skipped', () async {
      await start([_place(1, openNow: false)]);

      await service.handleGeofenceEnterForTest(1);

      expect(bridge.posted, isEmpty);
    });

    test('the hourly cap holds across the stream and geofence paths', () async {
      await start([_place(1), _place(2), _place(3)]);

      await service.handleGeofenceEnterForTest(1);
      await service.handleGeofenceEnterForTest(2);
      await service.handleGeofenceEnterForTest(3);

      expect(bridge.posted.map((n) => n.id), ['proximity_1', 'proximity_2']);
    });

    test('a notification the OS refused is not counted as sent', () async {
      bridge.postResult = false;
      await start([_place(1)]);

      await service.handleGeofenceEnterForTest(1);
      expect(data.logged, isEmpty);

      bridge.postResult = true;
      await service.handleGeofenceEnterForTest(1);
      expect(bridge.posted, hasLength(1));
    });

    test('an unknown place is ignored', () async {
      await start([_place(1)]);

      await service.handleGeofenceEnterForTest(99);

      expect(bridge.posted, isEmpty);
    });

    test('concurrent entries for one place only notify once', () async {
      await start([_place(1)]);

      await Future.wait([
        service.handleGeofenceEnterForTest(1),
        service.handleGeofenceEnterForTest(1),
      ]);

      expect(bridge.posted, hasLength(1));
    });
  });

  group('cold relaunch', () {
    test('acts on the saved snapshot before the network has loaded', () async {
      data.insights = {
        1: const ProximityInsight(
          savedMethod: 'instagram',
          creatorHandle: 'ramenking',
          topDish: 'tonkotsu',
        ),
      };
      await start([_place(1, savedMethod: 'instagram')]);

      // The process was killed. A fresh instance has no network data yet,
      // only what the last session left on disk.
      final relaunched = build();
      await relaunched.loadUserStateForTest('user-1');
      await relaunched.handleGeofenceEnterForTest(1, at: _near);

      final note = bridge.posted.single;
      expect(note.title, "@ramenking's pick is nearby");
      expect(note.body, contains('tonkotsu'));
    });

    test('an entry that arrives before sign-in state loads is dropped',
        () async {
      await service.handleGeofenceEnterForTest(1);

      expect(bridge.posted, isEmpty);
    });
  });

  group('tapping', () {
    test('routes the deep link to the app', () async {
      await start([_place(1)]);

      bridge.controller.add(const NotificationTapped({
        'deepLink': 'pinit://location/1',
        'locationId': '1',
      }));
      await Future<void>.delayed(Duration.zero);

      expect(taps.single.deepLink, 'pinit://location/1');
      expect(taps.single.payload['locationId'], '1');
    });

    test('a tap without a deep link does nothing', () async {
      await start([_place(1)]);

      bridge.controller.add(const NotificationTapped({'locationId': '1'}));
      await Future<void>.delayed(Duration.zero);

      expect(taps, isEmpty);
    });
  });

  group('asking for Always location', () {
    setUp(() => bridge.status = LocationAuthStatus.whenInUse);

    Future<void> saveSocialPlaceAfterBaseline() async {
      await start([_place(1)]); // baseline: already saved before this session
      await service.syncSavedLocations([
        _place(1),
        _place(2, savedMethod: 'tiktok'),
      ]);
      await Future<void>.delayed(Duration.zero);
    }

    test('asks after the first social save and requests Always on yes',
        () async {
      await saveSocialPlaceAfterBaseline();

      expect(presenterCalls, 1);
      expect(bridge.alwaysRequests, 1);
    });

    test('does not request Always when the user says not now', () async {
      presenterAnswer = false;
      await saveSocialPlaceAfterBaseline();

      expect(presenterCalls, 1);
      expect(bridge.alwaysRequests, 0);
    });

    test('existing social saves at sign-in never trigger the ask', () async {
      await start([_place(1, savedMethod: 'tiktok')]);
      await Future<void>.delayed(Duration.zero);

      expect(presenterCalls, 0);
    });

    test('an in-app save does not trigger the ask', () async {
      await start([_place(1)]);
      await service.syncSavedLocations([_place(1), _place(2)]);
      await Future<void>.delayed(Duration.zero);

      expect(presenterCalls, 0);
    });

    test('a social save found only via the insight still counts', () async {
      data.insights = {
        2: const ProximityInsight(savedMethod: 'instagram'),
      };
      await start([_place(1)]);
      await service.syncSavedLocations([_place(1), _place(2)]);
      await Future<void>.delayed(Duration.zero);

      expect(presenterCalls, 1);
    });

    test('stays pending when the app cannot show the sheet, then asks later',
        () async {
      presenterAnswer = null;
      await saveSocialPlaceAfterBaseline();
      expect(presenterCalls, 1);
      expect(bridge.alwaysRequests, 0);

      presenterAnswer = true;
      await service.maybePromptForAlwaysLocation();

      expect(presenterCalls, 2);
      expect(bridge.alwaysRequests, 1);
    });

    test('the pending ask survives a restart', () async {
      presenterAnswer = null;
      await saveSocialPlaceAfterBaseline();

      final relaunched = build();
      await relaunched.loadUserStateForTest('user-1');
      presenterAnswer = true;
      await relaunched.maybePromptForAlwaysLocation();

      expect(bridge.alwaysRequests, 1);
    });

    test('never asks twice in a row', () async {
      await saveSocialPlaceAfterBaseline();
      await service.syncSavedLocations([
        _place(1),
        _place(2, savedMethod: 'tiktok'),
        _place(3, savedMethod: 'instagram'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(presenterCalls, 1);
    });

    test('a later social save asks again only after two weeks', () async {
      presenterAnswer = false;
      await saveSocialPlaceAfterBaseline();
      expect(presenterCalls, 1);

      now = now.add(const Duration(days: 3));
      await service.syncSavedLocations([
        _place(1),
        _place(2, savedMethod: 'tiktok'),
        _place(3, savedMethod: 'instagram'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(presenterCalls, 1);

      now = now.add(const Duration(days: 15));
      await service.syncSavedLocations([
        _place(1),
        _place(2, savedMethod: 'tiktok'),
        _place(3, savedMethod: 'instagram'),
        _place(4, savedMethod: 'tiktok'),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(presenterCalls, 2);
    });

    test('nothing to offer once Always is granted', () async {
      bridge.status = LocationAuthStatus.always;
      await saveSocialPlaceAfterBaseline();

      expect(presenterCalls, 0);
    });

    test('waits while basic location access has not been decided', () async {
      bridge.status = LocationAuthStatus.notDetermined;
      await saveSocialPlaceAfterBaseline();
      expect(presenterCalls, 0);

      bridge.status = LocationAuthStatus.whenInUse;
      await service.maybePromptForAlwaysLocation();
      expect(presenterCalls, 1);
    });

    test('a denied user is not asked', () async {
      bridge.status = LocationAuthStatus.denied;
      await saveSocialPlaceAfterBaseline();

      expect(presenterCalls, 0);
    });
  });
}
