import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';

void main() {
  LocationModel buildLocation({
    String? cuisine,
    String? cuisinePrimary,
  }) {
    return LocationModel(
      locationId: 1,
      name: 'Test place',
      createdAt: DateTime(2026, 1, 1),
      cuisine: cuisine,
      cuisinePrimary: cuisinePrimary,
    );
  }

  test('displayCuisine capitalizes DB cuisine labels', () {
    expect(buildLocation(cuisine: 'american').displayCuisine, 'American');
    expect(buildLocation(cuisine: 'middle_eastern').displayCuisine,
        'Middle Eastern');
    expect(buildLocation(cuisine: 'British gastropub').displayCuisine,
        'British Gastropub');
    expect(buildLocation(cuisine: 'Korean-European').displayCuisine,
        'Korean-European');
    expect(buildLocation(cuisine: "Chinese (Xi'An)").displayCuisine,
        "Chinese (Xi'An)");
  });

  test('displayCuisine hides unknown and falls back to legacy cuisine', () {
    expect(buildLocation(cuisine: 'unknown').displayCuisine, isNull);
    expect(
      buildLocation(cuisine: 'british', cuisinePrimary: 'unknown')
          .displayCuisine,
      'British',
    );
  });
}
