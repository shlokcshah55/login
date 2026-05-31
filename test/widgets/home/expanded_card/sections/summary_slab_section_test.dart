import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_card/helpers/match_result.dart';
import 'package:login/widgets/home/expanded_card/sections/summary_slab_section.dart';

void main() {
  LocationModel buildLocation({
    String? cuisine,
    String? cuisinePrimary,
    int? reviewCount = 128,
  }) {
    return LocationModel(
      locationId: 1,
      name: 'Test place',
      createdAt: DateTime(2026, 1, 1),
      cuisine: cuisine,
      cuisinePrimary: cuisinePrimary,
      rating: 4.6,
      userRatingsTotal: reviewCount,
    );
  }

  Widget buildSubject(LocationModel location) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SummarySlabSection(
              location: location,
              match: const MatchResult(score: 0),
              matchAnim: const AlwaysStoppedAnimation<double>(1),
              onAddressTap: () {},
              onSavedFromTap: () {},
              isBeenTo: false,
              isBeenToLoading: false,
              onBeenTo: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows cuisine beside review metadata in title case',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(buildLocation(cuisinePrimary: 'middle_eastern')),
    );

    expect(find.text('128 reviews'), findsOneWidget);
    expect(find.text('Middle Eastern'), findsOneWidget);
    expect(find.text('middle_eastern'), findsNothing);
  });

  testWidgets('uses legacy cuisine when primary cuisine is unknown',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(
        buildLocation(cuisine: 'british gastropub', cuisinePrimary: 'unknown'),
      ),
    );

    expect(find.text('British Gastropub'), findsOneWidget);
    expect(find.text('unknown'), findsNothing);
  });

  testWidgets('hides cuisine when only unknown is available', (tester) async {
    await tester.pumpWidget(
      buildSubject(
          buildLocation(cuisine: 'unknown', cuisinePrimary: 'unknown')),
    );

    expect(find.text('unknown'), findsNothing);
    expect(find.byIcon(Icons.restaurant_menu_rounded), findsNothing);
  });
}
