import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/services/startup_cache/startup_snapshot_store.dart';
import 'package:login/services/startup_cache/startup_timing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _flushAsyncQueue() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsService', () {
    late AnalyticsService analytics;
    late List<Map<String, dynamic>> sentEvents;
    late DateTime currentTime;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      analytics = AnalyticsService();
      analytics.resetForTest();
      sentEvents = <Map<String, dynamic>>[];
      currentTime = DateTime.utc(2026, 4, 27, 12, 0, 0);

      analytics.setNowForTest(() => currentTime);
      analytics.setEventDispatcherForTest((params) async {
        sentEvents.add(Map<String, dynamic>.from(params));
      });

      await analytics.initialize(
        appVersion: '1.0.0',
        buildNumber: '12',
        platform: 'ios',
        osVersion: 'ios_18',
        locale: 'en-GB',
        timezone: 'Europe/London',
      );
    });

    tearDown(() {
      analytics.resetForTest();
    });

    test('buffers events before Supabase is ready and flushes later', () async {
      analytics.startSession(reason: 'app_launch');
      await _flushAsyncQueue();

      expect(sentEvents, isEmpty);

      analytics.setSupabaseReady();
      await _flushAsyncQueue();

      expect(
        sentEvents.map((event) => event['p_event_name']).toList(),
        containsAll(<String>['session_started', 'app_foregrounded']),
      );
    });

    test('tracks session lifecycle with open and active durations', () async {
      analytics.setSupabaseReady();
      analytics.startSession(reason: 'app_launch');

      currentTime = currentTime.add(const Duration(seconds: 5));
      analytics.registerUserInteraction(interactionKey: 'home_tap');

      currentTime = currentTime.add(const Duration(seconds: 20));
      analytics.endSession(reason: 'background');

      await _flushAsyncQueue();

      final eventNames =
          sentEvents.map((event) => event['p_event_name'] as String).toList();
      expect(
        eventNames,
        containsAll(<String>[
          'session_started',
          'app_foregrounded',
          'app_backgrounded',
          'session_ended',
        ]),
      );

      final ended = sentEvents.firstWhere(
        (event) => event['p_event_name'] == 'session_ended',
      );
      final props = Map<String, dynamic>.from(
        ended['p_properties'] as Map<String, dynamic>,
      );
      expect(ended['p_duration_ms'], 25000);
      expect(props['open_duration_ms'], 25000);
      expect(props['active_duration_ms'], 25000);
      expect(props['reason'], 'background');
    });

    test('emits rapid_tab_switch rage signal', () async {
      analytics.setSupabaseReady();
      analytics.startSession(reason: 'app_launch');

      analytics.trackTabSwitch(fromTab: 'home', toTab: 'bubbles');
      analytics.trackTabSwitch(fromTab: 'bubbles', toTab: 'profile');
      analytics.trackTabSwitch(fromTab: 'profile', toTab: 'home');
      analytics.trackTabSwitch(fromTab: 'home', toTab: 'bubbles');

      await _flushAsyncQueue();

      final rageEvents = sentEvents.where(
        (event) => event['p_event_name'] == 'rage_signal_detected',
      );
      expect(rageEvents.length, 1);

      final rageProps = Map<String, dynamic>.from(
        rageEvents.first['p_properties'] as Map<String, dynamic>,
      );
      expect(rageProps['signal_type'], 'rapid_tab_switch');
    });

    test('emits repeated_tap and repeated_error rage signals', () async {
      analytics.setSupabaseReady();
      analytics.startSession(reason: 'app_launch');

      for (var i = 0; i < 6; i++) {
        analytics.trackFeature(
          'search_opened',
          featureName: 'header_search',
          registerTap: true,
          interactionKey: 'search_opened',
        );
      }

      for (var i = 0; i < 3; i++) {
        analytics.recordError(key: 'deep_link_failed');
      }

      await _flushAsyncQueue();

      final rageEvents = sentEvents
          .where((event) => event['p_event_name'] == 'rage_signal_detected')
          .map(
            (event) => Map<String, dynamic>.from(
                event['p_properties'] as Map<String, dynamic>),
          )
          .toList();
      final signalTypes = rageEvents
          .map((properties) => properties['signal_type'] as String)
          .toSet();

      expect(signalTypes, contains('repeated_tap'));
      expect(signalTypes, contains('repeated_error'));
    });

    test('emits startup performance once with cache-safe properties', () async {
      analytics.setSupabaseReady();
      final timing = StartupTiming()
        ..markDartEntry()
        ..mark(StartupMilestone.runApp)
        ..recordSnapshotRead(
          const StartupSnapshotReadResult(
            status: StartupSnapshotReadStatus.miss,
          ),
          isPartial: false,
        )
        ..mark(StartupMilestone.firstUsableHome);

      analytics.trackStartupPerformance(timing);
      analytics.trackStartupPerformance(timing);
      await _flushAsyncQueue();

      final startupEvents = sentEvents.where(
        (event) => event['p_event_name'] == 'startup_performance',
      );
      expect(startupEvents, hasLength(1));
      final properties = Map<String, dynamic>.from(
        startupEvents.single['p_properties'] as Map<String, dynamic>,
      );
      expect(properties['snapshot_outcome'], 'miss');
      expect(properties, contains('first_usable_home_ms'));
      expect(properties, isNot(contains('user_id')));
    });

    test('emits low-cardinality startup refresh measurements', () async {
      analytics.setSupabaseReady();

      analytics.trackStartupRefresh(
        section: 'saved_locations',
        durationMs: 42,
        outcome: 'stale',
      );
      await _flushAsyncQueue();

      final event = sentEvents.singleWhere(
        (event) => event['p_event_name'] == 'startup_refresh',
      );
      expect(event['p_duration_ms'], 42);
      expect(event['p_properties'], <String, dynamic>{
        'section': 'saved_locations',
        'outcome': 'stale',
      });
    });
  });
}
