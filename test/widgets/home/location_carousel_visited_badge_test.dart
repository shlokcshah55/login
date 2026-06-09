import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/proximal_models.dart';
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

  testWidgets('carousel can show a swipe-up hint on the first item only',
      (tester) async {
    final locations = [
      LocationModel(
        locationId: 1,
        name: 'First Cafe',
        createdAt: DateTime(2026, 4, 15),
      ),
      LocationModel(
        locationId: 2,
        name: 'Second Cafe',
        createdAt: DateTime(2026, 4, 15),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 260,
            child: LocationCarousel(
              pageController: PageController(),
              locations: locations,
              showFirstItemSwipeHint: true,
              selectedMarkerId: null,
              bottomNavVisible: true,
              onPageChanged: (_) {},
              onLocationSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byKey(const ValueKey('first_carousel_swipe_hint')), findsOne);
  });

  testWidgets('carousel card shows magic search header and friend saves',
      (tester) async {
    final location = LocationModel(
      locationId: -11,
      name: 'Social Cafe',
      createdAt: DateTime(2026, 6, 9),
      magicSearchSectionTitle: 'Friends would pick these',
      friendSaves: const [
        FriendSave(
          friendId: 'friend-1',
          friendName: 'Maya Patel',
          friendUsername: 'maya',
          actionType: 'save',
          timestamp: '2026-06-08T12:00:00Z',
        ),
        FriendSave(
          friendId: 'friend-2',
          friendName: 'Leo Shah',
          actionType: 'save',
          timestamp: '2026-06-08T13:00:00Z',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            child: LocationCarousel(
              pageController: PageController(),
              locations: [location],
              selectedMarkerId: null,
              bottomNavVisible: true,
              onPageChanged: (_) {},
              onLocationSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Friends would pick these'), findsOneWidget);
    expect(find.text('Maya +1 saved'), findsOneWidget);
  });
}
