import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/been_to_rankings_section.dart';

void main() {
  testWidgets('shows top 3 by default, expands, and can collapse again', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BeenToRankingsSection(
            userId: 'user-1',
            showGateKeepToggle: false,
            seededPlaces: [
              _seed(rank: 1, name: 'Cafe One', rating: 9.6),
              _seed(rank: 2, name: 'Cafe Two', rating: 9.4),
              _seed(rank: 3, name: 'Cafe Three', rating: 9.2),
              _seed(rank: 4, name: 'Cafe Four', rating: 8.8),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Cafe One'), findsOneWidget);
    expect(find.text('Cafe Two'), findsOneWidget);
    expect(find.text('Cafe Three'), findsOneWidget);
    expect(find.text('Cafe Four'), findsNothing);
    expect(find.text('See more'), findsOneWidget);

    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();

    expect(find.text('Cafe Four'), findsOneWidget);
    expect(find.text('Show less'), findsOneWidget);

    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();

    expect(find.text('Cafe Four'), findsNothing);
    expect(find.text('See more'), findsOneWidget);
  });
}

BeenToRankedPlaceSeed _seed({
  required int rank,
  required String name,
  required double rating,
}) {
  return BeenToRankedPlaceSeed(
    rank: rank,
    userRating: rating,
    location: LocationModel(
      locationId: rank,
      name: name,
      createdAt: DateTime(2026, 5, 15),
      imageUrl: '',
    ),
  );
}
