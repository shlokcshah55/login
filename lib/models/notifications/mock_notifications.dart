import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notifications/user_added_to_bubble_notification.dart';
import 'package:login/models/notifications/video_processed_notification.dart';
import 'package:login/models/notifications/follow_request_notification.dart';
import 'package:login/models/notifications/follow_accepted_notification.dart';
import 'package:login/models/notifications/friend_visited_location_notification.dart';

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

      // User Added to Bubble Notification (read)
      UserAddedToBubbleNotification(
        id: '5',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
        inviterUsername: 'oliver_smith',
        inviterAvatar: 'https://i.pravatar.cc/150?img=4',
        inviterId: 'user_202',
        bubbleName: 'Weekend Hikers',
        bubbleId: 'bubble_321',
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
