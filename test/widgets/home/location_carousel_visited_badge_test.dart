import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/LocationCarousel/location_carousel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('carousel card shows a visited badge for been-to locations',
      (tester) async {
    final visitedLocation = LocationModel(
      locationId: 1,
      name: 'Test Cafe',
      createdAt: DateTime(2026, 4, 15),
      emoji: '☕',
      cuisine: 'Coffee',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 260,
            child: LocationCarousel(
              pageController: PageController(),
              locations: [visitedLocation],
              beenToLocationIds: const {1},
              selectedMarkerId: null,
              bottomNavVisible: true,
              onPageChanged: (_) {},
              onLocationSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Been'), findsOneWidget);
  });
}
