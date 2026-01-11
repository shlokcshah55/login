import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';

class FollowAcceptedNotification extends BaseNotification {
  final String username;
  final String userAvatar;
  final String userId;

  FollowAcceptedNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.username,
    required this.userAvatar,
    required this.userId,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.followAccepted,
        );

  /// Factory constructor from FCM data payload
  factory FollowAcceptedNotification.fromFCMData(Map<String, dynamic> data) {
    return FollowAcceptedNotification(
      id: data['id'] as String,
      // Handle both String (FCM) and DateTime (DB)
      timestamp: data['timestamp'] is String
          ? DateTime.parse(data['timestamp'] as String)
          : data['timestamp'] as DateTime,
      // Handle both explicit false and missing field
      isRead: data['isRead'] == true || data['isRead'] == 'true',
      username: data['username'] as String,
      userAvatar: data['userAvatar'] as String,
      userId: data['userId'] as String,
    );
  }

  @override
  String getAvatarUrl() => userAvatar;

  @override
  String getMessage() => '$username has accepted your follow request';

  @override
  String? getActionLabel() => null; // No button

  @override
  bool hasAction() => false;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'follow_accepted',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'username': username,
      'userAvatar': userAvatar,
      'userId': userId,
    };
  }

  @override
  String getNotificationTitle() => 'Follow Request Accepted';
}
