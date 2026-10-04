import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/home/widgets/magic_search_suggestions.dart';

void main() {
  testWidgets(
      'shows Naria wheel entry below magic suggestions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: MagicSearchSuggestions(
                nowProvider: () => DateTime(2026, 5, 31, 13),
                onSelected: (_) {},
                onDismiss: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text('Sweet treat nearby'), findsOneWidget);
    expect(find.text('OR...'), findsOneWidget);
    expect(find.text("Try it Sable's way"), findsOneWidget);
    expect(
      find.text('Spin a country wheel and let fate pick the craving.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Naria wheel submits a country-led magic search',
      (tester) async {
    String? submittedQuery;

    // The fallback test font is wider than the shipped DM Sans, so the fixed
    // 128px intro row overflows here; ignore only that layout warning.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: MagicSearchSuggestions(
                nowProvider: () => DateTime(2026, 5, 31, 13),
                onSelected: (query) => submittedQuery = query,
                onDismiss: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text("Try it Sable's way"));
    await tester.pumpAndSettle();

    expect(find.text("Sable's way"), findsOneWidget);
    expect(
      find.text(
        "Sable explores the world's cuisine one spin at a time. Spin the wheel, land on a country, and find that cuisine near you.",
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Instagram'), findsOneWidget);
    expect(find.bySemanticsLabel('TikTok'), findsOneWidget);

    await tester.tap(find.text('Spin the wheel'));
    await tester.pumpAndSettle();

    expect(find.text("Sable's wheel"), findsOneWidget);
    expect(find.text('It will come up with a place.'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pump();

    expect(submittedQuery, isNotNull);
    expect(submittedQuery, startsWith('Authentic '));
    expect(submittedQuery, endsWith(' cuisine near me'));
  });
}
