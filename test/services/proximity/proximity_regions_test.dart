import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/proximity/proximity_candidate.dart';
import 'package:login/services/proximity/proximity_policy.dart';
import 'package:login/services/proximity/proximity_regions.dart';
import 'package:login/utils/geo_types.dart';

ProximityCandidate _at(
  int id,
  double lat, {
  ProximitySource source = ProximitySource.inApp,
  ProximityInsight insight = const ProximityInsight(),
}) =>
    ProximityCandidate(
      locationId: id,
      name: 'Place $id',
      latitude: lat,
      longitude: 0,
      source: source,
      insight: insight,
    );

void main() {
  const policy = ProximityPolicy();
  final context = ProximityContext(now: DateTime(2026, 10, 5, 12));
  const here = LatLng(0, 0);

  List<String> ids(List<GeofenceRegion> regions) =>
      regions.map((r) => r.id).toList();

  test('nearest places win when the position is known', () {
    final regions = selectGeofenceRegions(
      candidates: [_at(1, 0.03), _at(2, 0.01), _at(3, 0.02)],
      policy: policy,
      context: context,
      position: here,
      maxRegions: 2,
    );
    expect(ids(regions), ['2', '3']);
  });

  test('without a position, social saves outrank in-app saves', () {
    final regions = selectGeofenceRegions(
      candidates: [
        _at(1, 0.01),
        _at(2, 0.02, source: ProximitySource.tiktok),
      ],
      policy: policy,
      context: context,
      maxRegions: 1,
    );
    expect(ids(regions), ['2']);
  });

  test('places that can never notify do not take a slot', () {
    final regions = selectGeofenceRegions(
      candidates: [
        _at(1, 0.001, insight: const ProximityInsight(beenTo: true)),
        _at(
          2,
          0.002,
          source: ProximitySource.tiktok,
          insight: const ProximityInsight(confidenceTier: 'low'),
        ),
        _at(3, 0.003),
        _at(4, 0.004),
      ],
      policy: policy,
      context: ProximityContext(
        now: context.now,
        lastSentByLocation: {4: context.now.subtract(const Duration(days: 1))},
      ),
      position: here,
    );
    expect(ids(regions), ['3']);
  });

  test('regions use the policy radius and the place coordinates', () {
    final region = selectGeofenceRegions(
      candidates: [_at(9, 0.01)],
      policy: policy,
      context: context,
      position: here,
    ).single;

    expect(region.id, '9');
    expect(region.latitude, 0.01);
    expect(region.radiusMeters, policy.config.radiusMeters);
    expect(region.toMap()['radius'], policy.config.radiusMeters);
  });

  test('never exceeds the default region budget', () {
    final regions = selectGeofenceRegions(
      candidates: [for (var i = 1; i <= 40; i++) _at(i, i * 0.001)],
      policy: policy,
      context: context,
      position: here,
    );
    expect(regions, hasLength(defaultMaxGeofenceRegions));
    expect(ids(regions).first, '1');
  });

  test('ties break by location id so results are stable', () {
    final regions = selectGeofenceRegions(
      candidates: [_at(5, 0.01), _at(2, 0.01)],
      policy: policy,
      context: context,
      position: here,
    );
    expect(ids(regions), ['2', '5']);
  });
}
