import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/home/onboarding/tour_hero_widgets.dart';

void main() {
  Future<void> pumpHero(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 300, child: child))),
      ),
    );
  }

  testWidgets('TikTokShareDemo advances through captions', (tester) async {
    await pumpHero(tester, const TikTokShareDemo());
    expect(find.text('1  TAP SHARE'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('2  SEND TO PINIT'), findsOneWidget);
  });

  testWidgets('ShareProcessingDemo and RewardsPathDemo build and animate',
      (tester) async {
    await pumpHero(tester, const ShareProcessingDemo());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);

    await pumpHero(tester, const RewardsPathDemo());
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('REFERRALS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
