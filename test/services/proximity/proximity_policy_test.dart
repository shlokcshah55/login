import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/proximity/proximity_candidate.dart';
import 'package:login/services/proximity/proximity_policy.dart';

ProximityCandidate _place(
  int id, {
  ProximitySource source = ProximitySource.inApp,
  ProximityInsight insight = const ProximityInsight(),
  double? rating,
  List<dynamic>? periods,
  bool? openNow,
}) =>
    ProximityCandidate(
      locationId: id,
      name: 'Place $id',
      latitude: 0,
      longitude: 0,
      source: source,
      insight: insight,
      rating: rating,
      openingHoursPeriods: periods,
      openNow: openNow,
    );

({ProximityCandidate candidate, double distanceMeters}) _at(
  ProximityCandidate c,
  double meters,
) =>
    (candidate: c, distanceMeters: meters);

void main() {
  const policy = ProximityPolicy();
  final noon = DateTime(2026, 10, 5, 12); // Monday midday, outside quiet hours

  ProximityContext ctx({
    DateTime? now,
    List<DateTime> sent = const [],
    Map<int, DateTime> last = const {},
  }) =>
      ProximityContext(
          now: now ?? noon, sentTimestamps: sent, lastSentByLocation: last);

  test('social save outranks an in-app save at the same distance', () {
    final result = policy.evaluate(
      candidates: [
        _at(_place(1), 300),
        _at(_place(2, source: ProximitySource.tiktok), 300),
      ],
      context: ctx(),
    );
    expect(result.selected.single.candidate.locationId, 2);
  });

  test('insight richness breaks ties between social saves', () {
    final plain = _place(1, source: ProximitySource.tiktok);
    final rich = _place(
      2,
      source: ProximitySource.tiktok,
      insight: const ProximityInsight(
        creatorHandle: 'foodie',
        topDish: 'miso cod',
        vibe: 'date night',
      ),
    );
    final result = policy.evaluate(
      candidates: [_at(plain, 400), _at(rich, 400)],
      context: ctx(),
    );
    expect(result.selected.single.candidate.locationId, 2);
  });

  test('closer wins when everything else is equal', () {
    final result = policy.evaluate(
      candidates: [_at(_place(1), 800), _at(_place(2), 100)],
      context: ctx(),
    );
    expect(result.selected.single.candidate.locationId, 2);
  });

  test('quiet hours block everything, including across midnight', () {
    for (final hour in [22, 23, 0, 3, 7]) {
      final result = policy.evaluate(
        candidates: [_at(_place(1), 100)],
        context: ctx(now: DateTime(2026, 10, 5, hour)),
      );
      expect(result.selected, isEmpty, reason: 'hour $hour');
      expect(result.globalReason, SuppressReason.quietHours);
    }
    final morning = policy.evaluate(
      candidates: [_at(_place(1), 100)],
      context: ctx(now: DateTime(2026, 10, 5, 8)),
    );
    expect(morning.selected, hasLength(1));
  });

  test('hourly and daily caps', () {
    final recent = [noon.subtract(const Duration(minutes: 10))];
    final twoInHour = [
      noon.subtract(const Duration(minutes: 10)),
      noon.subtract(const Duration(minutes: 40)),
    ];
    expect(
      policy.evaluate(
          candidates: [_at(_place(1), 100)],
          context: ctx(sent: twoInHour)).globalReason,
      SuppressReason.hourlyCap,
    );

    final threeToday = [
      noon.subtract(const Duration(hours: 2)),
      noon.subtract(const Duration(hours: 5)),
      noon.subtract(const Duration(hours: 9)),
    ];
    expect(
      policy.evaluate(
          candidates: [_at(_place(1), 100)],
          context: ctx(sent: threeToday)).globalReason,
      SuppressReason.dailyCap,
    );

    // One recent push still leaves budget.
    expect(
      policy.evaluate(
          candidates: [_at(_place(1), 100)],
          context: ctx(sent: recent)).selected,
      hasLength(1),
    );
  });

  test('per-place cooldown suppresses only that place', () {
    final result = policy.evaluate(
      candidates: [_at(_place(1), 100), _at(_place(2), 200)],
      context: ctx(last: {1: noon.subtract(const Duration(days: 1))}),
    );
    expect(result.suppressed[1], SuppressReason.cooldown);
    expect(result.selected.single.candidate.locationId, 2);

    final expired = policy.evaluate(
      candidates: [_at(_place(1), 100)],
      context: ctx(last: {1: noon.subtract(const Duration(days: 5))}),
    );
    expect(expired.selected, hasLength(1));
  });

  test('been-to places never notify', () {
    final visited = _place(1, insight: const ProximityInsight(beenTo: true));
    final result =
        policy.evaluate(candidates: [_at(visited, 100)], context: ctx());
    expect(result.suppressed[1], SuppressReason.beenTo);
  });

  test('closed and closing-soon places are suppressed', () {
    final closed = _place(1, openNow: false);
    final closing = _place(2, periods: [
      {
        'open': {'day': 1, 'time': '0900'},
        'close': {'day': 1, 'time': '1220'},
      }
    ]);
    final open = _place(3, openNow: true);
    final result = policy.evaluate(
      candidates: [_at(closed, 100), _at(closing, 100), _at(open, 100)],
      context: ctx(),
    );
    expect(result.suppressed[1], SuppressReason.closed);
    expect(result.suppressed[2], SuppressReason.closingSoon);
    expect(result.selected.single.candidate.locationId, 3);
  });

  test('unknown opening hours are allowed', () {
    final result =
        policy.evaluate(candidates: [_at(_place(1), 100)], context: ctx());
    expect(result.selected, hasLength(1));
  });

  test('unconfirmed low-confidence social saves are suppressed', () {
    ProximityCandidate social(int id, ProximityInsight i) =>
        _place(id, source: ProximitySource.instagram, insight: i);

    final result = policy.evaluate(
      candidates: [
        _at(social(1, const ProximityInsight(confidenceTier: 'medium')), 100),
        _at(
            social(
                2,
                const ProximityInsight(
                    confidenceTier: 'medium', confirmedByUser: true)),
            200),
        _at(social(3, const ProximityInsight(confidenceTier: 'high')), 300),
        _at(social(4, const ProximityInsight()), 400),
      ],
      context: ctx(),
    );
    expect(result.suppressed[1], SuppressReason.lowConfidence);
    expect(result.suppressed.containsKey(2), isFalse);
    expect(result.suppressed.containsKey(3), isFalse);
    expect(result.suppressed.containsKey(4), isFalse);
  });

  test('in-app saves ignore the confidence gate', () {
    final result = policy.evaluate(
      candidates: [
        _at(_place(1, insight: const ProximityInsight(confidenceTier: 'low')),
            100),
      ],
      context: ctx(),
    );
    expect(result.selected, hasLength(1));
  });

  test('places beyond the radius are dropped', () {
    final result =
        policy.evaluate(candidates: [_at(_place(1), 1500)], context: ctx());
    expect(result.suppressed[1], SuppressReason.outOfRadius);
  });

  test('maxPerEvent bounds the selection', () {
    const wide = ProximityPolicy(ProximityConfig(maxPerEvent: 2));
    final result = wide.evaluate(
      candidates: [
        _at(_place(1), 100),
        _at(_place(2), 200),
        _at(_place(3), 300),
      ],
      context: ctx(),
    );
    expect(result.selected.map((d) => d.candidate.locationId), [1, 2]);
  });

  test('selection never exceeds the remaining hourly budget', () {
    const wide = ProximityPolicy(ProximityConfig(maxPerEvent: 5));
    final result = wide.evaluate(
      candidates: [_at(_place(1), 100), _at(_place(2), 200)],
      context: ctx(sent: [noon.subtract(const Duration(minutes: 5))]),
    );
    expect(result.selected, hasLength(1));
  });

  test('score stays within 0..1', () {
    final best = _place(
      1,
      source: ProximitySource.tiktok,
      rating: 5,
      insight:
          const ProximityInsight(creatorHandle: 'a', topDish: 'b', vibe: 'c'),
    );
    expect(policy.score(best, 0), closeTo(1.0, 1e-9));
    expect(policy.score(_place(2, rating: 1), 1000), closeTo(0.0, 1e-9));
  });
}
