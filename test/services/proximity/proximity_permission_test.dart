import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/proximity/proximity_geofence_bridge.dart';
import 'package:login/services/proximity/proximity_permission.dart';

void main() {
  const policy = AlwaysPromptPolicy();
  final now = DateTime(2026, 10, 5, 12);

  bool ask({
    LocationAuthStatus status = LocationAuthStatus.whenInUse,
    bool pending = true,
    AlwaysPromptHistory history = const AlwaysPromptHistory(),
  }) =>
      policy.shouldPrompt(
        status: status,
        hasPendingSocialSave: pending,
        history: history,
        now: now,
      );

  test('asks after a social save when only While Using is granted', () {
    expect(ask(), isTrue);
  });

  test('never asks without a pending social save', () {
    expect(ask(pending: false), isFalse);
  });

  test('only While Using can be upgraded', () {
    expect(ask(status: LocationAuthStatus.always), isFalse);
    expect(ask(status: LocationAuthStatus.denied), isFalse);
    expect(ask(status: LocationAuthStatus.restricted), isFalse);
    expect(ask(status: LocationAuthStatus.notDetermined), isFalse);
    expect(ask(status: LocationAuthStatus.unsupported), isFalse);
  });

  test('a second ask waits at least two weeks', () {
    final recent = AlwaysPromptHistory(
      count: 1,
      lastAskedAt: now.subtract(const Duration(days: 3)),
    );
    final old = AlwaysPromptHistory(
      count: 1,
      lastAskedAt: now.subtract(const Duration(days: 15)),
    );
    expect(ask(history: recent), isFalse);
    expect(ask(history: old), isTrue);
  });

  test('stops asking after two attempts', () {
    final spent = AlwaysPromptHistory(
      count: 2,
      lastAskedAt: now.subtract(const Duration(days: 90)),
    );
    expect(ask(history: spent), isFalse);
  });

  test('history survives encoding and ignores corrupt data', () {
    final original = AlwaysPromptHistory(count: 1, lastAskedAt: now);
    final decoded = AlwaysPromptHistory.decode(original.encode());
    expect(decoded.count, 1);
    expect(decoded.lastAskedAt, now);

    expect(AlwaysPromptHistory.decode(null).count, 0);
    expect(AlwaysPromptHistory.decode('not json').count, 0);
    expect(const AlwaysPromptHistory().asked(now).count, 1);
  });
}
