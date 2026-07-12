import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/location_list_card.dart';

void main() {
  testWidgets('renders restaurant metadata and inbox status', (tester) async {
    var tapped = false;
    final location = LocationModel(
      locationId: 42,
      name: 'Noodle Yard',
      cuisine: 'Chinese',
      vicinity: 'Soho, London',
      createdAt: DateTime.utc(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationListCard(
            location: location,
            sourceLabel: 'TikTok',
            statusLabel: 'Saved',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Noodle Yard'), findsOneWidget);
    expect(find.text('Soho, London'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.byType(LocationListCard));
    expect(tapped, isTrue);
  });
}
