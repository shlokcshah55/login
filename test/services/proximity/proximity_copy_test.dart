import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/proximity/proximity_candidate.dart';
import 'package:login/services/proximity/proximity_copy.dart';
import 'package:login/services/proximity/proximity_hours.dart';
import 'package:login/services/proximity/proximity_policy.dart';

ProximityDecision _decision(
  ProximityCandidate c, {
  double meters = 300,
  OpeningStatus status = const OpeningStatus(OpenState.unknown),
}) =>
    ProximityDecision(
      candidate: c,
      distanceMeters: meters,
      score: 0.5,
      status: status,
    );

ProximityCandidate _c({
  ProximitySource source = ProximitySource.tiktok,
  ProximityInsight insight = const ProximityInsight(),
  String? cuisine,
  double? rating,
}) =>
    ProximityCandidate(
      locationId: 42,
      name: 'Nobu',
      latitude: 0,
      longitude: 0,
      source: source,
      insight: insight,
      cuisine: cuisine,
      rating: rating,
    );

void main() {
  test('social + creator + dish leads with the creator reason', () {
    final m = buildProximityMessage(_decision(_c(
      insight:
          const ProximityInsight(creatorHandle: 'foodie', topDish: 'miso cod'),
    )));
    expect(m.title, "@foodie's pick is nearby");
    expect(m.body, 'Try the miso cod at Nobu · 300m away');
    expect(m.metadata['creatorHandle'], '@foodie');
    expect(m.metadata['dish'], 'miso cod');
    expect(m.metadata['savedMethod'], 'tiktok');
  });

  test('does not double the @ on a handle that already has one', () {
    final m = buildProximityMessage(_decision(_c(
      insight: const ProximityInsight(creatorHandle: '@foodie'),
    )));
    expect(m.title, "@foodie's pick is nearby");
  });

  test('social + creator + vibe falls back to the vibe', () {
    final m = buildProximityMessage(_decision(_c(
      insight:
          const ProximityInsight(creatorHandle: 'foodie', vibe: 'date night'),
    )));
    expect(m.body, 'Nobu · date night · 300m away');
  });

  test('social with no creator names the platform', () {
    final m =
        buildProximityMessage(_decision(_c(source: ProximitySource.instagram)));
    expect(m.title, 'Saved from Instagram nearby');
    expect(m.body, 'Nobu is 300m away');
  });

  test('in-app save uses place facts', () {
    final m = buildProximityMessage(_decision(
      _c(source: ProximitySource.inApp, cuisine: 'Japanese', rating: 4.6),
    ));
    expect(m.title, 'Saved place nearby');
    expect(m.body, 'Nobu · Japanese · 4.6★ — 300m away');
  });

  test('in-app save with sparse data still reads cleanly', () {
    final m =
        buildProximityMessage(_decision(_c(source: ProximitySource.inApp)));
    expect(m.body, 'Nobu — 300m away');
  });

  test('appends closing time only when open with a known close', () {
    final closes = DateTime(2026, 10, 5, 23);
    final open = buildProximityMessage(_decision(
      _c(source: ProximitySource.inApp),
      status: OpeningStatus(OpenState.open, closesAt: closes),
    ));
    expect(open.body, endsWith('· open till 11pm'));
    expect(open.metadata['closesAt'], closes.toIso8601String());

    final unknown =
        buildProximityMessage(_decision(_c(source: ProximitySource.inApp)));
    expect(unknown.body, isNot(contains('open till')));
  });

  test('formatDistance', () {
    expect(formatDistance(4), '10m');
    expect(formatDistance(283), '280m');
    expect(formatDistance(999), '1000m');
    expect(formatDistance(1000), '1km');
    expect(formatDistance(1240), '1.2km');
  });

  test('formatClockTime', () {
    expect(formatClockTime(DateTime(2026, 1, 1, 0, 0)), '12am');
    expect(formatClockTime(DateTime(2026, 1, 1, 12, 30)), '12:30pm');
    expect(formatClockTime(DateTime(2026, 1, 1, 22, 0)), '10pm');
  });
}
