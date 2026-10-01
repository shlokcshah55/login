import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notifications/proximity_location_notification.dart';

void main() {
  Map<String, dynamic> row({Map<String, dynamic> metadata = const {}}) => {
        'id': 'n1',
        'type': 'proximity_location',
        'created_at': '2026-10-05T12:00:00Z',
        'is_read': false,
        'title': "@foodie's pick is nearby",
        'message': 'Try the miso cod at Nobu · 300m away',
        'metadata': {
          'locationId': '42',
          'locationName': 'Nobu',
          'distanceMeters': '300',
          ...metadata,
        },
      };

  test('uses the server copy and rich metadata when present', () {
    final n = BaseNotification.fromSupabase(row(metadata: {
      'creatorHandle': '@foodie',
      'dish': 'miso cod',
      'savedMethod': 'tiktok',
    })) as ProximityLocationNotification;

    expect(n.getMessage(), 'Try the miso cod at Nobu · 300m away');
    expect(n.getNotificationTitle(), "@foodie's pick is nearby");
    expect(n.creatorHandle, '@foodie');
    expect(n.dish, 'miso cod');
    expect(n.savedMethod, 'tiktok');
    expect(n.distanceMeters, 300);
  });

  test('older rows without copy fall back to the generic line', () {
    final legacy = row()
      ..['title'] = null
      ..['message'] = null;
    final n =
        BaseNotification.fromSupabase(legacy) as ProximityLocationNotification;

    expect(n.getMessage(), 'Nobu is 300m away');
    expect(n.getNotificationTitle(), 'Saved place nearby');
  });
}
