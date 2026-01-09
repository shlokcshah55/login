import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notifications/video_processed_notification.dart';
import 'package:login/models/notifications/follow_request_notification.dart';
import 'package:login/models/notifications/follow_accepted_notification.dart';
import 'package:login/models/notifications/friend_visited_location_notification.dart';
import 'package:login/models/notifications/friend_added_bubble_notification.dart';

class MockNotifications {
  static List<BaseNotification> getMockNotifications() {
    return [
      // Video Processed Notification (unread)
      VideoProcessedNotification(
        id: '1',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
        locationName: 'Sunset Beach Cafe',
        locationId: 'loc_123',
      ),

      // Follow Request Notification (unread)
      FollowRequestNotification(
        id: '2',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isRead: false,
        username: 'sarah_jones',
        userAvatar: 'https://i.pravatar.cc/150?img=1',
        userId: 'user_456',
      ),

      // Friend Visited Location Notification (unread)
      FriendVisitedLocationNotification(
        id: '3',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isRead: false,
        username: 'mike_wilson',
        userAvatar: 'https://i.pravatar.cc/150?img=2',
        userId: 'user_789',
        locationName: 'Central Park',
        locationId: 'loc_456',
      ),

      // Follow Accepted Notification (read)
      FollowAcceptedNotification(
        id: '4',
        timestamp: DateTime.now().subtract(const Duration(hours: 6)),
        isRead: true,
        username: 'emma_davis',
        userAvatar: 'https://i.pravatar.cc/150?img=3',
        userId: 'user_101',
      ),

      // Friend Added to Bubble Notification (read)
      FriendAddedToBubbleNotification(
        id: '5',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
        username: 'alex_chen',
        userAvatar: 'https://i.pravatar.cc/150?img=4',
        userId: 'user_202',
        bubbleName: 'Coffee Spots',
        bubbleId: 'bubble_789',
        locationName: 'Blue Bottle Coffee',
      ),

      // Video Processed Notification (read)
      VideoProcessedNotification(
        id: '6',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true,
        locationName: 'The Rooftop Bar',
        locationId: 'loc_789',
      ),

      // Follow Request Notification (read)
      FollowRequestNotification(
        id: '7',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        isRead: true,
        username: 'jessica_lee',
        userAvatar: 'https://i.pravatar.cc/150?img=5',
        userId: 'user_303',
      ),

      // Friend Visited Location Notification (read)
      FriendVisitedLocationNotification(
        id: '8',
        timestamp: DateTime.now().subtract(const Duration(days: 5)),
        isRead: true,
        username: 'david_park',
        userAvatar: 'https://i.pravatar.cc/150?img=6',
        userId: 'user_404',
        locationName: 'Golden Gate Bridge',
        locationId: 'loc_999',
      ),
    ];
  }
}
