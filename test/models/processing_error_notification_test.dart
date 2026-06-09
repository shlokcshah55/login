import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/notifications/processing_error_notification.dart';

void main() {
  test('generates platform-specific copy when backend copy is missing', () {
    final notification = ProcessingErrorNotification.fromFCMData({
      'id': 'notification-1',
      'timestamp': DateTime.utc(2026, 5, 29),
      'isRead': false,
      'errorType': 'not_enough_location_info',
      'sourceUrl': 'https://www.instagram.com/reel/abc123/',
    });

    expect(notification.title, "Couldn't find a place in this Reel");
    expect(
      notification.body,
      "The reel didn't include enough location detail. You can search for the place and add it manually.",
    );
  });

  test('keeps backend-provided title and body', () {
    final notification = ProcessingErrorNotification.fromFCMData({
      'id': 'notification-2',
      'timestamp': DateTime.utc(2026, 5, 29),
      'isRead': false,
      'title': 'Custom title',
      'body': 'Custom body',
      'errorType': 'not_enough_location_info',
      'sourceUrl': 'https://www.instagram.com/reel/abc123/',
    });

    expect(notification.title, 'Custom title');
    expect(notification.body, 'Custom body');
  });
}
