import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/social_review/widgets/social_place_search_sheet.dart';

void main() {
  testWidgets('searches, shows place context, and returns the selected result',
      (tester) async {
    LocationModel? selected;
    final result = LocationModel(
      locationId: -1,
      name: 'The Devonshire',
      vicinity: '17 Denman Street, London',
      rating: 4.4,
      googlePlaceId: 'google-devonshire',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialPlaceSearchPanel(
            autofocus: false,
            debounceDuration: Duration.zero,
            searcher: (_) async => [result],
            onSelected: (place) => selected = place,
          ),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Search restaurants, cafés or bars'),
      'Devon',
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('The Devonshire'), findsOneWidget);
    expect(find.text('17 Denman Street, London'), findsOneWidget);
    expect(find.text('4.4'), findsOneWidget);

    await tester.tap(find.text('The Devonshire'));
    expect(selected?.googlePlaceId, 'google-devonshire');
  });

  testWidgets('keeps useful guidance before a query', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialPlaceSearchPanel(
            autofocus: false,
            searcher: (_) async => const [],
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.text('Search by the place name, neighbourhood or address'),
      findsOneWidget,
    );
  });
}
