import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/notification_surface_visibility.dart';

void main() {
  test('remains visible until every notifications route exits', () {
    final visibility = NotificationSurfaceVisibility.instance;

    visibility.enter();
    visibility.enter();
    visibility.exit();
    expect(visibility.visible.value, isTrue);

    visibility.exit();
    expect(visibility.visible.value, isFalse);
  });
}
