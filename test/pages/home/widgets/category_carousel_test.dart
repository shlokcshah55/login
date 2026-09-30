import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/home/categories/category_glyph.dart';
import 'package:login/pages/home/categories/home_category.dart';
import 'package:login/pages/home/widgets/category_carousel.dart';

HomeCategory _category(
  HomeCategoryKind kind,
  String id,
  String label, {
  int count = 3,
  String? emoji,
  String? areaLabel,
}) {
  return HomeCategory(
    kind: kind,
    id: id,
    label: label,
    count: count,
    emoji: emoji,
    areaLabel: areaLabel,
    resolve: () async => const [],
  );
}

void main() {
  group('CategoryMark.resolve', () {
    test('matches cuisine keywords to food icons', () {
      final mark = CategoryMark.resolve(
        _category(HomeCategoryKind.cuisine, 'japanese', 'Japanese'),
      );
      expect(mark.icon, Icons.set_meal_rounded);
    });

    test('reads user-named lists for keywords', () {
      final mark = CategoryMark.resolve(
        _category(HomeCategoryKind.eatList, 'c1', 'Date night ideas'),
      );
      expect(mark.icon, Icons.favorite_rounded);
    });

    test('keys match at word starts only', () {
      final mark = CategoryMark.resolve(
        _category(HomeCategoryKind.eatList, 'c4', 'Chocolate run'),
      );
      expect(mark.icon, isNot(Icons.bedtime_rounded));
    });

    test('short keys only match whole words', () {
      final mark = CategoryMark.resolve(
        _category(HomeCategoryKind.eatList, 'c2', 'Barbecue crawl',
            emoji: '🔥'),
      );
      expect(mark.icon, isNull);
      expect(mark.emoji, '🔥');
    });

    test('bubbles always get the group mark, whatever their name', () {
      final mark = CategoryMark.resolve(
        _category(HomeCategoryKind.bubble, 'b1', 'Date night crew'),
      );
      expect(mark.icon, Icons.groups_rounded);
    });

    test('falls back to a monogram when nothing fits', () {
      final mark = CategoryMark.resolve(
        _category(HomeCategoryKind.eatList, 'c3', 'Zanzibar list'),
      );
      expect(mark.monogram, 'Z');
    });
  });

  testWidgets('renders chips, group dots and See all', (tester) async {
    HomeCategory? tapped;
    var seeAllTapped = false;
    final categories = [
      _category(HomeCategoryKind.source, 'tiktok', 'TikTok', count: 64),
      _category(HomeCategoryKind.cuisine, 'italian', 'Italian', count: 13),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: CategoryCarousel(
            categories: categories,
            bottomNavVisible: true,
            onCategorySelected: (c) => tapped = c,
            onSeeAll: () => seeAllTapped = true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('64 SAVES'), findsOneWidget);
    expect(find.text('13 SPOTS'), findsOneWidget);
    expect(find.byType(CategoryGlyph), findsNWidgets(2));

    await tester.tap(find.text('Italian'));
    await tester.pumpAndSettle();
    expect(tapped?.id, 'italian');

    await tester.tap(find.text('SEE ALL'));
    await tester.pumpAndSettle();
    expect(seeAllTapped, isTrue);
  });

  testWidgets('area cuisine and bubble chips show their meta lines',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final categories = [
      _category(HomeCategoryKind.cuisine, 'korean', 'Korean',
          count: 16, areaLabel: 'Islington'),
      _category(HomeCategoryKind.bubble, 'b1', 'Sunday Crew', count: 6),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: CategoryCarousel(
            categories: categories,
            bottomNavVisible: true,
            onCategorySelected: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ISLINGTON · 16'), findsOneWidget);
    expect(find.text('BUBBLE · 6'), findsOneWidget);
    // No member photos → the generated glyph stands in.
    expect(find.byType(CategoryGlyph), findsNWidgets(2));
    expect(
      find.bySemanticsLabel(RegExp('Korean in Islington, 16 places')),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
