import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/widgets/proximity_priming_sheet.dart';

void main() {
  Future<bool?> open(WidgetTester tester, Future<void> Function() act) async {
    bool? result;
    var resolved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await showProximityPrimingSheet(context);
                  resolved = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    expect(resolved, isTrue);
    return result;
  }

  testWidgets('explains the benefit and the Always prompt', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProximityPrimingSheet())),
    );

    expect(find.text("Get a nudge when you're near a place you saved"),
        findsOneWidget);
    expect(find.textContaining('TikTok or Instagram'), findsOneWidget);
    expect(find.textContaining('"Always"'), findsOneWidget);
    expect(find.textContaining('never leaves'), findsOneWidget);
    expect(find.text('Turn on nudges'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('Turn on nudges resolves to true', (tester) async {
    final result = await open(
      tester,
      () => tester.tap(find.text('Turn on nudges')),
    );
    expect(result, isTrue);
  });

  testWidgets('Not now resolves to false', (tester) async {
    final result = await open(
      tester,
      () => tester.tap(find.text('Not now')),
    );
    expect(result, isFalse);
  });

  testWidgets('dismissing without choosing resolves to null', (tester) async {
    final result = await open(
      tester,
      () => tester.tapAt(const Offset(10, 10)),
    );
    expect(result, isNull);
  });
}
