import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/signup_wizard/steps/bubble_invite_step.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/services/onboarding_analytics.dart';
import 'package:login/supabase/helpers/auth.dart';
import 'package:login/supabase/service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class _MockSupabase extends Mock implements SupabaseService {}

class _MockAuthHelper extends Mock implements AuthHelper {}

class _MockUserData extends Mock implements UserDataProvider {}

class _MockAnalytics extends Mock implements AnalyticsService {}

void main() {
  late _MockSupabase supabase;
  late _MockAuthHelper authHelper;
  late _MockUserData userData;
  late OnboardingAnalytics analytics;

  setUp(() {
    supabase = _MockSupabase();
    authHelper = _MockAuthHelper();
    userData = _MockUserData();
    when(() => supabase.users).thenReturn(authHelper);
    when(() => userData.supabaseUserData).thenReturn(null);
    when(() => authHelper.getSuggestedUsers()).thenAnswer(
      (_) async => [
        UserModel(
          supabaseId: 'u1',
          name: 'Maya Patel',
          email: 'm@x.dev',
          username: 'maya',
        ),
        UserModel(
          supabaseId: 'u2',
          name: 'Leo Grant',
          email: 'l@x.dev',
          username: 'leo',
        ),
      ],
    );
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

  Future<void> pump(WidgetTester tester, {VoidCallback? onSkip}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SupabaseService>.value(value: supabase),
          ChangeNotifierProvider<UserDataProvider>.value(value: userData),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: BubbleInviteStep(
              analytics: analytics,
              onFinish: () {},
              onSkip: onSkip ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('lists people already on Pinit to quick add', (tester) async {
    await pump(tester);

    expect(find.text('Better with friends'), findsOneWidget);
    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('@leo'), findsOneWidget);
    expect(find.text('ADD'), findsNWidgets(2));
  });

  testWidgets('adding someone updates the call to action', (tester) async {
    await pump(tester);

    expect(find.text('CREATE BUBBLE'), findsOneWidget);

    await tester.tap(find.text('Maya'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ADDED'), findsOneWidget);
    expect(find.text('FOLLOW 1 PERSON'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Friday Crew');
    await tester.pump();
    expect(find.text('CREATE BUBBLE + FOLLOW 1'), findsOneWidget);
  });

  testWidgets('skip is always available', (tester) async {
    var skipped = 0;
    await pump(tester, onSkip: () => skipped++);

    await tester.tap(find.text('SKIP'));
    await tester.pump();

    expect(skipped, 1);
  });
}
