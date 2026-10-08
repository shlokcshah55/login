import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/carousel_list_page.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/widgets/home/location_list_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LocationModel savedLocation({
    required int id,
    required String name,
    required DateTime savedAt,
  }) {
    return LocationModel(
      locationId: id,
      name: name,
      createdAt: DateTime(2026, 1, id),
      savedAt: savedAt,
    ).setPreference(LocationPreference.saved);
  }

  testWidgets('saved list sorts by most recently added first', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CarouselListPage(
          title: 'Your Saves',
          listType: LocationListType.saved,
          locations: [
            savedLocation(
              id: 1,
              name: 'Older Save',
              savedAt: DateTime(2026, 4, 1, 10),
            ),
            savedLocation(
              id: 2,
              name: 'Newest Save',
              savedAt: DateTime(2026, 4, 3, 10),
            ),
            savedLocation(
              id: 3,
              name: 'Middle Save',
              savedAt: DateTime(2026, 4, 2, 10),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();

    expect(find.text('Last added'), findsOneWidget);
    expect(find.byType(LocationListCard), findsNWidgets(3));

    final newestTop = tester.getTopLeft(find.text('Newest Save')).dy;
    final middleTop = tester.getTopLeft(find.text('Middle Save')).dy;
    final olderTop = tester.getTopLeft(find.text('Older Save')).dy;

    expect(newestTop, lessThan(middleTop));
    expect(middleTop, lessThan(olderTop));
  });

  LocationModel place({
    required int id,
    required String name,
    required String cuisineKey,
    double? lat = 51.5,
  }) {
    return LocationModel(
      locationId: id,
      name: name,
      createdAt: DateTime(2026, 1, id),
      cuisineKey: cuisineKey,
      lat: lat,
      lng: lat == null ? null : -0.1,
    ).setPreference(LocationPreference.saved);
  }

  Widget page(List<LocationModel> locations) => MaterialApp(
        home: CarouselListPage(
          title: 'Your Saves',
          listType: LocationListType.saved,
          locations: locations,
        ),
      );

  testWidgets('cuisine chips filter tiles and clear restores them',
      (tester) async {
    await tester.pumpWidget(page([
      place(id: 1, name: 'Luigi', cuisineKey: 'italian'),
      place(id: 2, name: 'Tokyo Bar', cuisineKey: 'japanese'),
      place(id: 3, name: 'Nonna', cuisineKey: 'italian'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.byType(LocationListCard), findsNWidgets(3));
    expect(find.text('SEE ON MAP · 3'), findsOneWidget);

    await tester.tap(find.text('Italian'));
    await tester.pumpAndSettle();
    expect(find.byType(LocationListCard), findsNWidgets(2));
    expect(find.text('Tokyo Bar'), findsNothing);
    expect(find.text('SEE ON MAP · 2'), findsOneWidget);

    await tester.tap(find.text('CLEAR'));
    await tester.pumpAndSettle();
    expect(find.byType(LocationListCard), findsNWidgets(3));
  });

  testWidgets('searching matches cuisine and narrows the chip rail',
      (tester) async {
    await tester.pumpWidget(page([
      place(id: 1, name: 'Luigi', cuisineKey: 'italian'),
      place(id: 2, name: 'Tokyo Bar', cuisineKey: 'japanese'),
    ]));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'japan');
    await tester.pumpAndSettle();

    expect(find.byType(LocationListCard), findsOneWidget);
    expect(find.text('Tokyo Bar'), findsOneWidget);
    expect(find.text('Italian'), findsNothing);
  });

  testWidgets('locating a place on the map leaves See All for the map',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CarouselListPage(
                  title: 'Your Saves',
                  listType: LocationListType.saved,
                  locations: [
                    savedLocation(
                      id: 1,
                      name: 'Only Save',
                      savedAt: DateTime(2026, 4, 1),
                    ),
                  ],
                ),
              ),
            ),
            child: const Text('Home map'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Home map'));
    await tester.pumpAndSettle();
    expect(find.byType(CarouselListPage), findsOneWidget);

    final card = tester.widget<LocationListCard>(find.byType(LocationListCard));
    expect(card.onShowOnMap, isNotNull);
    card.onShowOnMap!();
    await tester.pumpAndSettle();

    expect(find.byType(CarouselListPage), findsNothing);
    expect(find.text('Home map'), findsOneWidget);
  });
}
