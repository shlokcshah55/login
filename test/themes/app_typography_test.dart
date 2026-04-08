import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/themes/app_widget_themes.dart';
import 'package:login/widgets/home/LocationCarousel/location_carousel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('brand text styles use Rova while body styles use Manrope', () {
    expect(AppTypography.textTheme.displayLarge?.fontFamily, 'Rova');
    expect(AppTypography.textTheme.headlineMedium?.fontFamily, 'Rova');
    expect(AppTypography.textTheme.labelLarge?.fontFamily, 'Rova');

    expect(AppTypography.textTheme.bodyLarge?.fontFamily, 'Manrope');
    expect(AppTypography.textTheme.bodyMedium?.fontFamily, 'Manrope');
  });

  test('shared button themes no longer use Poppins', () {
    final elevatedStyle = AppWidgetThemes.elevatedButtonTheme.style;
    final outlinedStyle = AppWidgetThemes.outlinedButtonTheme.style;

    expect(
      elevatedStyle?.textStyle?.resolve({})?.fontFamily,
      isNot('Poppins'),
    );
    expect(
      outlinedStyle?.textStyle?.resolve({})?.fontFamily,
      isNot('Poppins'),
    );
  });

  test('brand helper applies breathable default spacing', () {
    final style = AppTypography.brand(fontSize: 18);

    expect(style.letterSpacing, greaterThan(0));
    expect(style.height, greaterThan(1));
  });

  testWidgets('discovery carousel location title uses Rova', (tester) async {
    final location = LocationModel(
      locationId: 1,
      name: 'Test Cafe',
      createdAt: DateTime(2026, 4, 7),
      emoji: '☕',
      cuisine: 'Coffee',
      generatedSummary: 'Bright coffee and pastries',
      rating: 4.7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 260,
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

    final titleText = tester.widget<Text>(find.text('Test Cafe'));

    expect(titleText.style?.fontFamily, 'Rova');
  });
}
