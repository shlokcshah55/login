import 'package:login/services/startup_cache/startup_snapshot_store.dart';

enum StartupMilestone {
  runApp,
  firstFrame,
  snapshotRead,
  cachedProvidersUsable,
  firstUsableHome,
  profileRefresh,
  savedLocationsRefresh,
  markerBuild,
}

enum StartupSnapshotOutcome {
  hit,
  partialHit,
  miss,
  corrupt,
  unsupportedSchema,
  ownershipMismatch,
  tooLarge,
  disabled,
}

abstract interface class StartupTimingClock {
  Duration get elapsed;
  bool get isRunning;
  void start();
}

class StartupTiming {
  StartupTiming({StartupTimingClock? clock})
      : _clock = clock ?? _StopwatchStartupTimingClock();

  final StartupTimingClock _clock;
  final Map<StartupMilestone, int> _elapsedMilliseconds = {};
  StartupSnapshotOutcome? _snapshotOutcome;
  int? _snapshotByteSize;
  bool _hasTakenStartupPerformance = false;

  void markDartEntry() {
    if (!_clock.isRunning) _clock.start();
  }

  void mark(StartupMilestone milestone) {
    markDartEntry();
    _elapsedMilliseconds.putIfAbsent(
      milestone,
      () => _clock.elapsed.inMilliseconds,
    );
  }

  int? elapsedFor(StartupMilestone milestone) =>
      _elapsedMilliseconds[milestone];

  void recordSnapshotRead(
    StartupSnapshotReadResult result, {
    required bool isPartial,
  }) {
    mark(StartupMilestone.snapshotRead);
    _snapshotByteSize = result.byteSize;
    _snapshotOutcome = switch (result.status) {
      StartupSnapshotReadStatus.hit => isPartial
          ? StartupSnapshotOutcome.partialHit
          : StartupSnapshotOutcome.hit,
      StartupSnapshotReadStatus.miss => StartupSnapshotOutcome.miss,
      StartupSnapshotReadStatus.corrupt => StartupSnapshotOutcome.corrupt,
      StartupSnapshotReadStatus.unsupportedSchema =>
        StartupSnapshotOutcome.unsupportedSchema,
      StartupSnapshotReadStatus.ownershipMismatch =>
        StartupSnapshotOutcome.ownershipMismatch,
      StartupSnapshotReadStatus.tooLarge => StartupSnapshotOutcome.tooLarge,
    };
  }

  void recordSnapshotDisabled() {
    mark(StartupMilestone.snapshotRead);
    _snapshotByteSize = 0;
    _snapshotOutcome = StartupSnapshotOutcome.disabled;
  }

  Map<String, dynamic> startupPerformanceProperties() {
    final properties = <String, dynamic>{};
    for (final entry in _elapsedMilliseconds.entries) {
      properties['${_snakeCase(entry.key.name)}_ms'] = entry.value;
    }
    final snapshotOutcome = _snapshotOutcome;
    if (snapshotOutcome != null) {
      properties['snapshot_outcome'] = _snakeCase(snapshotOutcome.name);
    }
    final snapshotByteSize = _snapshotByteSize;
    if (snapshotByteSize != null) {
      properties['snapshot_bytes'] = snapshotByteSize;
    }
    return properties;
  }

  Map<String, dynamic>? takeStartupPerformanceProperties() {
    if (_hasTakenStartupPerformance) return null;
    _hasTakenStartupPerformance = true;
    return startupPerformanceProperties();
  }

  String _snakeCase(String value) {
    return value.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
    );
  }
}

class _StopwatchStartupTimingClock implements StartupTimingClock {
  final Stopwatch _stopwatch = Stopwatch();

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  bool get isRunning => _stopwatch.isRunning;

  @override
  void start() => _stopwatch.start();
}

final StartupTiming startupTiming = StartupTiming();
