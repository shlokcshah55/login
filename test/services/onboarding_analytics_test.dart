import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/services/onboarding_analytics.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockAnalytics analytics;
  late List<Map<String, dynamic>> events;

  setUp(() {
    analytics = _MockAnalytics();
    events = [];
    when(
      () => analytics.track(
        eventName: any(named: 'eventName'),
        eventCategory: any(named: 'eventCategory'),
        screenName: any(named: 'screenName'),
        featureName: any(named: 'featureName'),
        durationMs: any(named: 'durationMs'),
        occurredAt: any(named: 'occurredAt'),
        properties: any(named: 'properties'),
      ),
    ).thenAnswer((invocation) {
      events.add({
        'name': invocation.namedArguments[#eventName],
        'category': invocation.namedArguments[#eventCategory],
        'props': invocation.namedArguments[#properties],
      });
    });
  });

  test('emits viewed/completed/skipped with step and flow', () {
    final a = OnboardingAnalytics(flow: 'google', analytics: analytics);

    a.viewed(OnboardingStep.firstSave);
    a.completed(OnboardingStep.firstSave, method: 'share');
    a.viewed(OnboardingStep.preferences);
    a.skipped(OnboardingStep.preferences);

    expect(events.map((e) => e['name']), [
      'onboarding_step_viewed',
      'onboarding_step_completed',
      'onboarding_step_viewed',
      'onboarding_step_skipped',
    ]);
    expect(events.every((e) => e['category'] == 'onboarding'), isTrue);
    expect(events[1]['props'], containsPair('step', 'first_save'));
    expect(events[1]['props'], containsPair('method', 'share'));
    expect(events[1]['props'], containsPair('flow', 'google'));
    expect(events[1]['props'], contains('elapsed_ms'));
  });

  test('first_save and finished are timed from account creation', () {
    final a = OnboardingAnalytics(flow: 'email', analytics: analytics);
    a.markAccountCreated();

    a.firstSave(method: 'link');
    a.finished();

    expect(events[0]['name'], 'onboarding_first_save');
    expect(events[0]['props']['elapsed_ms'], isA<int>());
    expect(events[1]['name'], 'onboarding_finished');
  });

  test('only sends properties the server whitelists', () {
    final a = OnboardingAnalytics(flow: 'apple', analytics: analytics);
    a.viewed(OnboardingStep.bubble);

    final keys = (events.single['props'] as Map).keys.toSet();
    expect(keys.difference({'step', 'flow', 'method', 'elapsed_ms'}), isEmpty);
  });
}
