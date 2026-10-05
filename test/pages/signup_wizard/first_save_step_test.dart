import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/signup_wizard/first_save_watcher.dart';
import 'package:login/pages/signup_wizard/steps/first_save_step.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/services/onboarding_analytics.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

class _FakeWatcher implements FirstSaveWatcher {
  final StreamController<void> controller = StreamController<void>.broadcast();
  bool started = false;
  bool disposed = false;

  @override
  Stream<void> get onFirstSave => controller.stream;

  @override
  bool get hasFired => false;

  @override
  void start() => started = true;

  @override
  Future<bool> check() async => false;

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  late _FakeWatcher watcher;
  late OnboardingAnalytics analytics;

  setUp(() {
    watcher = _FakeWatcher();
    final mock = _MockAnalytics();
    when(
      () => mock.track(
        eventName: any(named: 'eventName'),
        eventCategory: any(named: 'eventCategory'),
        screenName: any(named: 'screenName'),
        featureName: any(named: 'featureName'),
        durationMs: any(named: 'durationMs'),
        occurredAt: any(named: 'occurredAt'),
        properties: any(named: 'properties'),
      ),
    ).thenReturn(null);
    analytics = OnboardingAnalytics(flow: 'email', analytics: mock);
  });

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onDone,
    VoidCallback? onSkip,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirstSaveStep(
            analytics: analytics,
            watcher: watcher,
            onDone: onDone ?? () {},
            onSkip: onSkip ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the first-save prompt and starts watching', (tester) async {
    await pump(tester);
    expect(find.text('Save your first place'), findsOneWidget);
    expect(find.text('IMPORT FROM NOTES'), findsOneWidget);
    expect(watcher.started, isTrue);
  });

  testWidgets('celebrates and advances once a save is detected',
      (tester) async {
    var done = 0;
    await pump(tester, onDone: () => done++);

    watcher.controller.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('First place saved'), findsOneWidget);
    expect(done, 0);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(done, 1);
  });

  testWidgets('skip calls onSkip', (tester) async {
    var skipped = 0;
    await pump(tester, onSkip: () => skipped++);

    await tester.tap(find.text('SKIP FOR NOW'));
    await tester.pump();

    expect(skipped, 1);
  });

  testWidgets('a save after skipping does not advance the flow again',
      (tester) async {
    var done = 0;
    await pump(tester, onDone: () => done++, onSkip: () {});

    await tester.tap(find.text('SKIP FOR NOW'));
    await tester.pump();
    watcher.controller.add(null);
    await tester.pump(const Duration(seconds: 3));

    expect(done, 0);
  });
}
