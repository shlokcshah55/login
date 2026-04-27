import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef AnalyticsEventDispatcher = Future<void> Function(
  Map<String, dynamic> params,
);

class AnalyticsService {
  AnalyticsService._internal();

  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;

  static const String _anonIdKey = 'analytics_anon_id_v1';
  static const int _maxBufferedEvents = 400;
  static const Duration _idleTimeout = Duration(seconds: 30);
  static const Duration _rapidTabSwitchWindow = Duration(seconds: 4);
  static const Duration _repeatedTapWindow = Duration(seconds: 2);
  static const Duration _repeatedErrorWindow = Duration(seconds: 30);
  static const int _rapidTabSwitchThreshold = 4;
  static const int _repeatedTapThreshold = 6;
  static const int _repeatedErrorThreshold = 3;

  final List<Map<String, dynamic>> _bufferedEvents = <Map<String, dynamic>>[];
  final Queue<DateTime> _recentTabSwitches = Queue<DateTime>();
  final Map<String, Queue<DateTime>> _recentTapEvents =
      <String, Queue<DateTime>>{};
  final Map<String, Queue<DateTime>> _recentErrorEvents =
      <String, Queue<DateTime>>{};

  DateTime Function() _now = DateTime.now;
  AnalyticsEventDispatcher? _eventDispatcherOverride;

  bool _initialized = false;
  bool _supabaseReady = false;
  bool _isFlushing = false;

  String? _anonId;
  String? _userId;
  String? _sessionId;
  String? _lastScreenName;

  String _appVersion = 'unknown';
  String _buildNumber = 'unknown';
  String _platform = 'unknown';
  String _osVersion = 'unknown';
  String _locale = 'und';
  String _timezone = 'UTC';

  DateTime? _foregroundStartedAt;
  DateTime? _activeWindowStartAt;
  DateTime? _lastInteractionAt;
  bool _sessionActive = false;

  String? get anonId => _anonId;
  String? get sessionId => _sessionId;
  String? get userId => _userId;

  Future<void> initialize({
    String? appVersion,
    String? buildNumber,
    String? platform,
    String? osVersion,
    String? locale,
    String? timezone,
  }) async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final storedAnonId = prefs.getString(_anonIdKey);
    if (storedAnonId != null && storedAnonId.trim().isNotEmpty) {
      _anonId = storedAnonId;
    } else {
      _anonId = _generateUuidV4();
      await prefs.setString(_anonIdKey, _anonId!);
    }

    _appVersion = _sanitizeValue(appVersion, fallback: 'unknown');
    _buildNumber = _sanitizeValue(buildNumber, fallback: 'unknown');
    _platform = _sanitizeValue(platform, fallback: _resolvePlatform());
    _osVersion = _sanitizeValue(osVersion, fallback: _resolveOsVersion());
    _locale = _sanitizeValue(locale, fallback: _resolveLocale());
    _timezone = _sanitizeValue(timezone, fallback: _resolveTimezone());
    _initialized = true;
  }

  void setSupabaseReady({bool ready = true}) {
    _supabaseReady = ready;
    if (_supabaseReady) {
      unawaited(_flushBufferedEvents());
    }
  }

  void setUser(String? userId) {
    _userId = userId;
  }

  void startSession({String reason = 'app_launch'}) {
    if (!_initialized || _sessionActive) return;

    final now = _now();
    _sessionId = _generateSessionId();
    _foregroundStartedAt = now;
    _activeWindowStartAt = now;
    _lastInteractionAt = now;
    _sessionActive = true;

    track(
      eventName: 'session_started',
      eventCategory: 'lifecycle',
      properties: <String, dynamic>{'reason': reason},
      occurredAt: now,
    );
    track(
      eventName: 'app_foregrounded',
      eventCategory: 'lifecycle',
      properties: <String, dynamic>{'reason': reason},
      occurredAt: now,
    );
  }

  void endSession({required String reason}) {
    if (!_initialized || !_sessionActive) return;

    final now = _now();
    final openDurationMs = _foregroundStartedAt == null
        ? null
        : now.difference(_foregroundStartedAt!).inMilliseconds;
    final activeDurationMs = _finalizeActiveDuration(now);

    track(
      eventName: 'app_backgrounded',
      eventCategory: 'lifecycle',
      durationMs: openDurationMs,
      properties: <String, dynamic>{
        'reason': reason,
        'active_duration_ms': activeDurationMs,
        'open_duration_ms': openDurationMs,
      },
      occurredAt: now,
    );
    track(
      eventName: 'session_ended',
      eventCategory: 'lifecycle',
      durationMs: openDurationMs,
      properties: <String, dynamic>{
        'reason': reason,
        'active_duration_ms': activeDurationMs,
        'open_duration_ms': openDurationMs,
      },
      occurredAt: now,
    );

    _sessionActive = false;
    _foregroundStartedAt = null;
    _activeWindowStartAt = null;
    _lastInteractionAt = null;
    _lastScreenName = null;
  }

  void registerUserInteraction({String? interactionKey}) {
    if (!_sessionActive) return;

    final now = _now();
    final lastInteraction = _lastInteractionAt;
    if (lastInteraction != null &&
        now.difference(lastInteraction) > _idleTimeout) {
      _activeWindowStartAt = now;
    } else {
      _activeWindowStartAt ??= now;
    }
    _lastInteractionAt = now;

    if (interactionKey != null && interactionKey.trim().isNotEmpty) {
      _registerTap(interactionKey.trim());
    }
  }

  void trackScreen(String screenName) {
    final normalized = screenName.trim();
    if (normalized.isEmpty) return;
    if (_lastScreenName == normalized) return;
    _lastScreenName = normalized;

    track(
      eventName: 'screen_view',
      eventCategory: 'navigation',
      screenName: normalized,
      properties: <String, dynamic>{'screen_name': normalized},
    );
  }

  void trackTabSwitch({
    required String fromTab,
    required String toTab,
    String trigger = 'tap',
  }) {
    final now = _now();
    track(
      eventName: 'tab_switched',
      eventCategory: 'navigation',
      screenName: toTab,
      properties: <String, dynamic>{
        'from_tab': fromTab,
        'to_tab': toTab,
        'trigger': trigger,
      },
      occurredAt: now,
    );

    _recentTabSwitches.addLast(now);
    while (_recentTabSwitches.isNotEmpty &&
        now.difference(_recentTabSwitches.first) > _rapidTabSwitchWindow) {
      _recentTabSwitches.removeFirst();
    }
    if (_recentTabSwitches.length >= _rapidTabSwitchThreshold) {
      trackRageSignal(
        signalType: 'rapid_tab_switch',
        properties: <String, dynamic>{
          'from_tab': fromTab,
          'to_tab': toTab,
          'switch_count': _recentTabSwitches.length,
          'window_ms': _rapidTabSwitchWindow.inMilliseconds,
        },
      );
      _recentTabSwitches.clear();
    }
  }

  void trackFeature(
    String eventName, {
    required String featureName,
    String? screenName,
    Map<String, dynamic>? properties,
    bool registerTap = false,
    String? interactionKey,
  }) {
    if (registerTap) {
      _registerTap(interactionKey ?? featureName);
    }
    track(
      eventName: eventName,
      eventCategory: 'feature',
      featureName: featureName,
      screenName: screenName,
      properties: properties,
    );
  }

  void trackRageSignal({
    required String signalType,
    Map<String, dynamic>? properties,
  }) {
    final merged = <String, dynamic>{
      'signal_type': signalType,
      ...?properties,
    };
    track(
      eventName: 'rage_signal_detected',
      eventCategory: 'quality',
      properties: merged,
    );
  }

  void recordError({
    required String key,
    Map<String, dynamic>? properties,
  }) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return;

    final now = _now();
    final queue = _recentErrorEvents.putIfAbsent(
      normalizedKey,
      () => Queue<DateTime>(),
    );
    queue.addLast(now);
    while (queue.isNotEmpty &&
        now.difference(queue.first) > _repeatedErrorWindow) {
      queue.removeFirst();
    }

    if (queue.length >= _repeatedErrorThreshold) {
      trackRageSignal(
        signalType: 'repeated_error',
        properties: <String, dynamic>{
          'key': normalizedKey,
          'count': queue.length,
          'window_ms': _repeatedErrorWindow.inMilliseconds,
          ...?properties,
        },
      );
      queue.clear();
    }
  }

  void track({
    required String eventName,
    required String eventCategory,
    String? screenName,
    String? featureName,
    int? durationMs,
    DateTime? occurredAt,
    Map<String, dynamic>? properties,
  }) {
    if (!_initialized) return;
    if (_sessionId == null || _sessionId!.isEmpty) {
      _sessionId = _generateSessionId();
    }

    final normalizedEventName = eventName.trim().toLowerCase();
    final normalizedEventCategory = eventCategory.trim().toLowerCase();
    if (normalizedEventName.isEmpty || normalizedEventCategory.isEmpty) return;

    final params = <String, dynamic>{
      'p_event_name': normalizedEventName,
      'p_event_category': normalizedEventCategory,
      'p_session_id': _sessionId,
      'p_anon_id': _anonId,
      'p_screen_name': _nullableTrim(screenName),
      'p_feature_name': _nullableTrim(featureName),
      'p_duration_ms': durationMs,
      'p_occurred_at': (occurredAt ?? _now()).toUtc().toIso8601String(),
      'p_app_version': _appVersion,
      'p_build_number': _buildNumber,
      'p_platform': _platform,
      'p_os_version': _osVersion,
      'p_locale': _locale,
      'p_timezone': _timezone,
      'p_properties': properties ?? <String, dynamic>{},
    };

    _enqueueOrSend(params);
  }

  void _enqueueOrSend(Map<String, dynamic> params) {
    if (!_supabaseReady) {
      if (_bufferedEvents.length >= _maxBufferedEvents) {
        _bufferedEvents.removeAt(0);
      }
      _bufferedEvents.add(params);
      return;
    }
    unawaited(_dispatchEvent(params));
  }

  Future<void> _flushBufferedEvents() async {
    if (_isFlushing || !_supabaseReady || _bufferedEvents.isEmpty) return;
    _isFlushing = true;
    try {
      while (_bufferedEvents.isNotEmpty && _supabaseReady) {
        final event = _bufferedEvents.removeAt(0);
        await _dispatchEvent(event);
      }
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _dispatchEvent(Map<String, dynamic> params) async {
    try {
      if (_eventDispatcherOverride != null) {
        await _eventDispatcherOverride!(params);
        return;
      }

      await SupabaseClientManager().client.rpc(
            'track_app_event',
            params: params,
          );
    } catch (error) {
      if (kDebugMode) {
        print(
            'AnalyticsService: failed to track ${params['p_event_name']}: $error');
      }
    }
  }

  int _finalizeActiveDuration(DateTime now) {
    final activeStart = _activeWindowStartAt;
    final lastInteraction = _lastInteractionAt;
    if (activeStart == null || lastInteraction == null) return 0;

    final activeEndCandidate = lastInteraction.add(_idleTimeout);
    final boundedActiveEnd =
        activeEndCandidate.isBefore(now) ? activeEndCandidate : now;
    if (!boundedActiveEnd.isAfter(activeStart)) return 0;
    return boundedActiveEnd.difference(activeStart).inMilliseconds;
  }

  void _registerTap(String key) {
    final now = _now();
    final queue = _recentTapEvents.putIfAbsent(key, () => Queue<DateTime>());
    queue.addLast(now);
    while (
        queue.isNotEmpty && now.difference(queue.first) > _repeatedTapWindow) {
      queue.removeFirst();
    }

    if (queue.length >= _repeatedTapThreshold) {
      trackRageSignal(
        signalType: 'repeated_tap',
        properties: <String, dynamic>{
          'key': key,
          'count': queue.length,
          'window_ms': _repeatedTapWindow.inMilliseconds,
        },
      );
      queue.clear();
    }
  }

  String _sanitizeValue(String? value, {required String fallback}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return trimmed;
  }

  String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String _resolvePlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  String _resolveOsVersion() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  String _resolveLocale() {
    try {
      return WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
    } catch (_) {
      return 'und';
    }
  }

  String _resolveTimezone() {
    final name = DateTime.now().timeZoneName.trim();
    if (name.isEmpty) return 'UTC';
    return name;
  }

  String _generateSessionId() {
    final random = Random.secure();
    final nowMs = _now().millisecondsSinceEpoch;
    final randomPart =
        random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'sess_${nowMs}_$randomPart';
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}'
        '-${hex(bytes[4])}${hex(bytes[5])}'
        '-${hex(bytes[6])}${hex(bytes[7])}'
        '-${hex(bytes[8])}${hex(bytes[9])}'
        '-${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }

  @visibleForTesting
  void setNowForTest(DateTime Function() nowProvider) {
    _now = nowProvider;
  }

  @visibleForTesting
  void setEventDispatcherForTest(AnalyticsEventDispatcher? dispatcher) {
    _eventDispatcherOverride = dispatcher;
  }

  @visibleForTesting
  void resetForTest() {
    _initialized = false;
    _supabaseReady = false;
    _isFlushing = false;
    _anonId = null;
    _userId = null;
    _sessionId = null;
    _lastScreenName = null;
    _foregroundStartedAt = null;
    _activeWindowStartAt = null;
    _lastInteractionAt = null;
    _sessionActive = false;
    _bufferedEvents.clear();
    _recentTabSwitches.clear();
    _recentTapEvents.clear();
    _recentErrorEvents.clear();
    _now = DateTime.now;
    _eventDispatcherOverride = null;
    _appVersion = 'unknown';
    _buildNumber = 'unknown';
    _platform = 'unknown';
    _osVersion = 'unknown';
    _locale = 'und';
    _timezone = 'UTC';
  }
}
