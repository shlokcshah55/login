import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/home/widgets/magic_search_suggestions.dart';

void main() {
  testWidgets(
      'shows Naria wheel entry below magic suggestions',
      skip: true, // ARCHIVED: "Try it Kaian's way" entry point is hidden; re-enable when restored.
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
    expect(find.text("Try it Kaian's way"), findsOneWidget);
    expect(
      find.text('Spin a country wheel and let fate pick the craving.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Naria wheel submits a country-led magic search',
      skip: true, // ARCHIVED: "Try it Kaian's way" entry point is hidden; re-enable when restored.
      (tester) async {
    String? submittedQuery;

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

    await tester.tap(find.text("Try it Kaian's way"));
    await tester.pumpAndSettle();

    expect(find.text("Kaian's way"), findsOneWidget);
    expect(
      find.text(
        "Kaian is exploring the world's cuisine without leaving London. He spins a wheel and finds a restaurant. Try it out in your city.",
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Instagram'), findsOneWidget);
    expect(find.bySemanticsLabel('TikTok'), findsOneWidget);

    await tester.tap(find.text('Spin the wheel'));
    await tester.pumpAndSettle();

    expect(find.text("Naria's wheel"), findsOneWidget);
    expect(find.text('It will come up with a place.'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pump();

    expect(submittedQuery, isNotNull);
    expect(submittedQuery, startsWith('Cool '));
    expect(submittedQuery, endsWith(' cuisine'));
  });
}
