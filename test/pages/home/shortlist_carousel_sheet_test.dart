import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/widgets/mode_toggle.dart';
import 'package:login/pages/home/widgets/shortlist_carousel_sheet.dart';
import 'package:login/providers/shortlist_provider.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LocationModel location({
    required int id,
    required String name,
  }) {
    return LocationModel(
      locationId: id,
      name: name,
      createdAt: DateTime(2026, 1, id),
      emoji: '⭐️',
    );
  }

  testWidgets('swiping up removes an item from the shortlist', (tester) async {
    final provider = ShortlistProvider()
      ..add(location(id: 1, name: 'First'))
      ..add(location(id: 2, name: 'Second'));

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ShortlistProvider>.value(
          value: provider,
          child: Scaffold(
            body: ShortlistCarouselSheet(
              items: provider.items.toList(),
              currentMode: HomeMode.explore,
              onReturnToMode: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(provider.contains(1), isTrue);
    expect(find.text('First'), findsOneWidget);

    final dismissible =
        find.byKey(const ValueKey<String>('shortlist_remove_1'));
    expect(dismissible, findsOneWidget);

    await tester.fling(dismissible, const Offset(0, -500), 1500);
    await tester.pumpAndSettle();

    expect(provider.contains(1), isFalse);
    expect(find.text('First'), findsNothing);
    expect(provider.contains(2), isTrue);
  });
}
