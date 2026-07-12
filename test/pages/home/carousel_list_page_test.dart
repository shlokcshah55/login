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
}
