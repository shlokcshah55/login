import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/signup_wizard/steps/dietary_tag_label.dart';

void main() {
  group('formatDietaryTagLabel', () {
    test('replaces underscores with spaces for display labels', () {
      expect(formatDietaryTagLabel('gluten_free'), 'gluten free');
    });

    test('leaves already formatted labels unchanged', () {
      expect(formatDietaryTagLabel('vegan'), 'vegan');
    });
  });
}
