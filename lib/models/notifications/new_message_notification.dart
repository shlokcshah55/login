import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';

class NewMessageNotification extends BaseNotification {
  final String username;
  final String userAvatar;
  final String userId;
  final String bubbleName;
  final String content;


  NewMessageNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.username,
    required this.userAvatar,
    required this.userId,
    required this.bubbleName,
    required this.content,

  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.friendVisitedLocation,
        );

  /// Factory constructor from FCM data payload
  factory NewMessageNotification.fromFCMData(Map<String, dynamic> data) {
    return NewMessageNotification(
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
      bubbleName: data['bubbleName'] as String,
      content: data['content'] as String,
    );
  }

  @override
  String getAvatarUrl() => userAvatar;

  @override
  String getMessage() => '$username sent a new message in $bubbleName: "$content"';

  @override
  String? getActionLabel() => 'View';

  @override
  bool hasAction() => true;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'friend_visited_location',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'username': username,
      'userAvatar': userAvatar,
      'userId': userId,
      'bubbleName': bubbleName,
      'content': content,
    };
  }

  @override
  String getNotificationTitle() => 'New Message from $username';
}
