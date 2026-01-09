import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:login/models/notification_type.dart';
import 'package:login/models/notifications/video_processed_notification.dart';
import 'package:login/models/notifications/follow_request_notification.dart';
import 'package:login/models/notifications/follow_accepted_notification.dart';
import 'package:login/models/notifications/friend_visited_location_notification.dart';
import 'package:login/models/notifications/friend_added_bubble_notification.dart';

abstract class BaseNotification {
  final String id;
  final DateTime timestamp;
  final bool isRead;
  final NotificationType type;

  BaseNotification({
    required this.id,
    required this.timestamp,
    required this.isRead,
    required this.type,
  });

  // Abstract methods for child classes to implement
  String getAvatarUrl();
  String getMessage();
  String? getActionLabel();
  bool hasAction();

  /// Convert notification to FCM data payload (for backend reference)
  Map<String, dynamic> toFCMData();

  /// Get notification title for FCM
  String getNotificationTitle();

  /// Get notification body for FCM (same as getMessage but for consistency)
  String getNotificationBody() => getMessage();

  /// Get formatted timestamp (e.g., "5 minutes ago", "2 hours ago", "3 days ago")
  String getFormattedTimestamp() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    }
  }

  /// Factory method to create notification from FCM RemoteMessage
  static BaseNotification? fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    if (type == null) return null;

    try {
      switch (type) {
        case 'video_processed':
          return VideoProcessedNotification.fromFCMData(data);
        case 'follow_request':
          return FollowRequestNotification.fromFCMData(data);
        case 'follow_accepted':
          return FollowAcceptedNotification.fromFCMData(data);
        case 'friend_visited_location':
          return FriendVisitedLocationNotification.fromFCMData(data);
        case 'friend_added_bubble':
          return FriendAddedToBubbleNotification.fromFCMData(data);
        default:
          print('Unknown notification type: $type');
          return null;
      }
    } catch (e) {
      print('Error parsing notification: $e');
      return null;
    }
  }
}
