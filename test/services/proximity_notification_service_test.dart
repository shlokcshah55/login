import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/proximity/proximity_candidate.dart';
import 'package:login/services/proximity/proximity_copy.dart';
import 'package:login/services/proximity/proximity_data_source.dart';
import 'package:login/services/proximity_notification_service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDataSource implements ProximityDataSource {
  Map<int, ProximityInsight> insights = {};
  List<({int locationId, DateTime sentAt})> log = [];
  final List<int> logged = [];

  @override
  Future<Map<int, ProximityInsight>> fetchInsights() async => insights;

  @override
  Future<List<({int locationId, DateTime sentAt})>> fetchRecentLog({
    Duration window = const Duration(days: 4),
  }) async =>
      log;

  @override
  Future<void> logSent(int locationId) async => logged.add(locationId);
}

const _lat = 51.5;
const _lng = -0.1;

// ~100 m north of the places, and ~5.5 km away.
const _near = LatLng(_lat + 0.0009, _lng);
const _far = LatLng(_lat + 0.05, _lng);

LocationModel _place(
  int id, {
  String? savedMethod,
  List<dynamic>? periods,
  bool? openNow,
  double? rating,
}) =>
    LocationModel(
      locationId: id,
      name: 'Place $id',
      lat: _lat,
      lng: _lng,
      createdAt: DateTime.utc(2025, 1, 1),
      savedMethod: savedMethod,
      openingHoursPeriods: periods,
      openNow: openNow,
      rating: rating,
    );

void main() {
  late _FakeDataSource data;
  late List<ProximityMessage> sent;
  late bool sendResult;
  late DateTime now;
  late ProximityNotificationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    data = _FakeDataSource();
    sent = [];
    sendResult = true;
    now = DateTime(2026, 10, 5, 12); // Monday, midday
    service = ProximityNotificationService.withDependencies(
      dataSource: data,
      sender: (userId, message) async {
        if (sendResult) sent.add(message);
        return sendResult;
      },
      now: () => now,
    );
  });

  Future<void> start(List<LocationModel> places) async {
    await service.loadUserStateForTest('user-1');
    await service.syncSavedLocations(places);
  }

  test('a social save sends creator-led copy and logs to the server', () async {
    data.insights = {
      1: const ProximityInsight(
        savedMethod: 'tiktok',
        creatorHandle: 'foodie',
        topDish: 'miso cod',
        confidenceTier: 'high',
      ),
    };
    await start([_place(1, savedMethod: 'tiktok')]);

    await service.processPosition(_near);

    expect(sent, hasLength(1));
    expect(sent.single.title, "@foodie's pick is nearby");
    expect(sent.single.body, startsWith('Try the miso cod at Place 1'));
    expect(data.logged, [1]);
  });

  test('leaving and re-entering inside the cooldown does not resend', () async {
    await start([_place(1)]);

    await service.processPosition(_near);
    await service.processPosition(_far);
    await service.processPosition(_near);

    expect(sent, hasLength(1));
  });

  test('re-entering after the cooldown sends again', () async {
    await start([_place(1)]);

    await service.processPosition(_near);
    await service.processPosition(_far);
    now = now.add(const Duration(days: 5));
    await service.processPosition(_near);

    expect(sent, hasLength(2));
  });

  test('the social save wins, then the other follows on the next update',
      () async {
    data.insights = {
      2: const ProximityInsight(savedMethod: 'tiktok', creatorHandle: 'foodie'),
    };
    await start([_place(1), _place(2, savedMethod: 'tiktok')]);

    await service.processPosition(_near);
    expect(sent.single.metadata['locationId'], '2');
    // The runner-up is still pending, not consumed.
    expect(service.insideLocationIds, {2});

    await service.processPosition(_near);
    expect(sent.map((m) => m.metadata['locationId']), ['2', '1']);
  });

  test('a closed place fires once it opens while the user is still nearby',
      () async {
    final opensAt1pm = [
      {
        'open': {'day': 1, 'time': '1300'},
        'close': {'day': 1, 'time': '2300'},
      }
    ];
    await start([_place(1, periods: opensAt1pm)]);

    await service.processPosition(_near);
    expect(sent, isEmpty);
    expect(service.insideLocationIds, isEmpty);

    now = DateTime(2026, 10, 5, 13, 30);
    await service.processPosition(_near);
    expect(sent, hasLength(1));
    expect(sent.single.body, contains('open till 11pm'));
  });

  test('quiet hours defer the push until morning', () async {
    await start([_place(1)]);

    now = DateTime(2026, 10, 5, 23);
    await service.processPosition(_near);
    expect(sent, isEmpty);

    now = DateTime(2026, 10, 6, 9);
    await service.processPosition(_near);
    expect(sent, hasLength(1));
  });

  test('been-to places are consumed without a push', () async {
    data.insights = {1: const ProximityInsight(beenTo: true)};
    await start([_place(1)]);

    await service.processPosition(_near);
    await service.processPosition(_near);

    expect(sent, isEmpty);
    expect(service.insideLocationIds, {1});
  });

  test('unconfirmed medium-confidence social saves stay quiet', () async {
    data.insights = {
      1: const ProximityInsight(
          savedMethod: 'instagram', confidenceTier: 'medium'),
    };
    await start([_place(1, savedMethod: 'instagram')]);

    await service.processPosition(_near);

    expect(sent, isEmpty);
  });

  test('the server log carries cooldowns across devices', () async {
    data.log = [
      (locationId: 1, sentAt: now.subtract(const Duration(hours: 3)))
    ];
    await start([_place(1)]);

    await service.processPosition(_near);

    expect(sent, isEmpty);
  });

  test('a failed send is not retried on every location tick', () async {
    sendResult = false;
    await start([_place(1)]);

    await service.processPosition(_near);
    sendResult = true;
    await service.processPosition(_near);

    expect(sent, isEmpty);
    expect(data.logged, isEmpty);
  });

  test('places beyond the radius never notify', () async {
    await start([_place(1)]);

    await service.processPosition(_far);

    expect(sent, isEmpty);
    expect(service.insideLocationIds, isEmpty);
  });

  test('state survives a restart through shared preferences', () async {
    await start([_place(1)]);
    await service.processPosition(_near);
    expect(sent, hasLength(1));

    final restarted = ProximityNotificationService.withDependencies(
      dataSource: data,
      sender: (userId, message) async {
        sent.add(message);
        return true;
      },
      now: () => now,
    );
    await restarted.loadUserStateForTest('user-1');
    await restarted.syncSavedLocations([_place(1)]);
    await restarted.processPosition(_far);
    await restarted.processPosition(_near);

    expect(sent, hasLength(1));
  });
}
