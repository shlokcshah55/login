import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/notification_routes.dart';

void main() {
  group('resolveNotificationDeepLink', () {
    test('uses existing deepLink when present', () {
      expect(
        resolveNotificationDeepLink({
          'deepLink': 'pinit://user/u1',
          'type': 'follow_request',
          'userId': 'u2',
        }),
        'pinit://user/u1',
      );
    });

    test('follow_request -> user profile', () {
      expect(
        resolveNotificationDeepLink({'type': 'follow_request', 'userId': 'u1'}),
        'pinit://user/u1',
      );
    });

    test('follow_accepted -> user profile', () {
      expect(
        resolveNotificationDeepLink(
            {'type': 'follow_accepted', 'userId': 'u1'}),
        'pinit://user/u1',
      );
    });

    test('proximity_location -> location card', () {
      expect(
        resolveNotificationDeepLink(
            {'type': 'proximity_location', 'locationId': '42'}),
        'pinit://location/42',
      );
    });

    test('proximity_locaiton alias -> location card', () {
      expect(
        resolveNotificationDeepLink(
            {'type': 'proximity_locaiton', 'locationId': '42'}),
        'pinit://location/42',
      );
    });

    test('user_added_to_bubble -> bubble chat', () {
      expect(
        resolveNotificationDeepLink(
            {'type': 'user_added_to_bubble', 'bubbleId': 'b1'}),
        'pinit://bubble/b1',
      );
    });

    test('new_message -> bubble chat', () {
      expect(
        resolveNotificationDeepLink({'type': 'new_message', 'bubbleId': 'b1'}),
        'pinit://bubble/b1',
      );
    });

    test('video_processed -> notifications layover', () {
      expect(
        resolveNotificationDeepLink({'type': 'video_processed'}),
        'pinit://notifications',
      );
    });

    test('location_saved alias -> notifications layover', () {
      expect(
        resolveNotificationDeepLink({'type': 'location_saved'}),
        'pinit://notifications',
      );
    });

    test('missing IDs -> null', () {
      expect(resolveNotificationDeepLink({'type': 'follow_request'}), isNull);
      expect(resolveNotificationDeepLink({'type': 'new_message'}), isNull);
      expect(
          resolveNotificationDeepLink({'type': 'proximity_location'}), isNull);
    });

    test('unknown type -> null', () {
      expect(resolveNotificationDeepLink({'type': 'something_else'}), isNull);
    });
  });
}
