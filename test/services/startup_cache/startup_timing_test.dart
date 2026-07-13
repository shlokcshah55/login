import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/startup_cache/startup_snapshot_store.dart';
import 'package:login/services/startup_cache/startup_timing.dart';

void main() {
  test('records monotonic milestone duration once', () {
    final clock = _FakeStartupTimingClock();
    final timing = StartupTiming(clock: clock)..markDartEntry();

    clock.elapse(const Duration(milliseconds: 12));
    timing.mark(StartupMilestone.runApp);
    clock.elapse(const Duration(milliseconds: 8));
    timing.mark(StartupMilestone.runApp);
    timing.mark(StartupMilestone.firstFrame);

    expect(timing.elapsedFor(StartupMilestone.runApp), 12);
    expect(timing.elapsedFor(StartupMilestone.firstFrame), 20);
  });

  test('projects snapshot status and partial hits without personal data', () {
    final clock = _FakeStartupTimingClock();
    final timing = StartupTiming(clock: clock)..markDartEntry();
    clock.elapse(const Duration(milliseconds: 5));

    timing.recordSnapshotRead(
      const StartupSnapshotReadResult(
        status: StartupSnapshotReadStatus.hit,
        byteSize: 2048,
      ),
      isPartial: true,
    );
    timing.mark(StartupMilestone.cachedProvidersUsable);
    timing.mark(StartupMilestone.firstUsableHome);

    final properties = timing.takeStartupPerformanceProperties();

    expect(properties, isNotNull);
    expect(properties!['snapshot_outcome'], 'partial_hit');
    expect(properties['snapshot_bytes'], 2048);
    expect(properties['snapshot_read_ms'], 5);
    expect(properties['cached_providers_usable_ms'], 5);
    expect(properties['first_usable_home_ms'], 5);
    expect(properties.keys, isNot(contains('user_id')));
    expect(timing.takeStartupPerformanceProperties(), isNull);
  });

  test('projects non-hit snapshot outcomes', () {
    for (final entry in <StartupSnapshotReadStatus, String>{
      StartupSnapshotReadStatus.miss: 'miss',
      StartupSnapshotReadStatus.corrupt: 'corrupt',
      StartupSnapshotReadStatus.unsupportedSchema: 'unsupported_schema',
      StartupSnapshotReadStatus.ownershipMismatch: 'ownership_mismatch',
      StartupSnapshotReadStatus.tooLarge: 'too_large',
    }.entries) {
      final timing = StartupTiming(clock: _FakeStartupTimingClock())
        ..markDartEntry()
        ..recordSnapshotRead(
          StartupSnapshotReadResult(status: entry.key),
          isPartial: false,
        );

      expect(
        timing.startupPerformanceProperties()['snapshot_outcome'],
        entry.value,
      );
    }
  });
}

class _FakeStartupTimingClock implements StartupTimingClock {
  Duration _elapsed = Duration.zero;

  @override
  Duration get elapsed => _elapsed;

  @override
  bool get isRunning => true;

  void elapse(Duration duration) {
    _elapsed += duration;
  }

  @override
  void start() {}
}
