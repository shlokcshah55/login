import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';

class FollowRequestNotification extends BaseNotification {
  final String username;
  final String userAvatar;
  final String userId;

  FollowRequestNotification({
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
          type: NotificationType.followRequest,
        );

  /// Factory constructor from FCM data payload
  factory FollowRequestNotification.fromFCMData(Map<String, dynamic> data) {
    return FollowRequestNotification(
      id: data['id'] as String,
      timestamp: DateTime.parse(data['timestamp'] as String),
      isRead: false, // New notifications are always unread
      username: data['username'] as String,
      userAvatar: data['userAvatar'] as String,
      userId: data['userId'] as String,
    );
  }

  @override
  String getAvatarUrl() => userAvatar;

  @override
  String getMessage() => '$username has requested to follow you';

  @override
  String? getActionLabel() => 'Accept';

  @override
  bool hasAction() => true;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'follow_request',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'username': username,
      'userAvatar': userAvatar,
      'userId': userId,
    };
  }

  @override
  String getNotificationTitle() => 'New Follow Request';
}
