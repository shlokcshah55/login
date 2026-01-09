import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';

class FriendAddedToBubbleNotification extends BaseNotification {
  final String username;
  final String userAvatar;
  final String userId;
  final String bubbleName;
  final String bubbleId;
  final String locationName;

  FriendAddedToBubbleNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.username,
    required this.userAvatar,
    required this.userId,
    required this.bubbleName,
    required this.bubbleId,
    required this.locationName,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.friendAddedToBubble,
        );

  /// Factory constructor from FCM data payload
  factory FriendAddedToBubbleNotification.fromFCMData(Map<String, dynamic> data) {
    return FriendAddedToBubbleNotification(
      id: data['id'] as String,
      timestamp: DateTime.parse(data['timestamp'] as String),
      isRead: false, // New notifications are always unread
      username: data['username'] as String,
      userAvatar: data['userAvatar'] as String,
      userId: data['userId'] as String,
      bubbleName: data['bubbleName'] as String,
      bubbleId: data['bubbleId'] as String,
      locationName: data['locationName'] as String,
    );
  }

  @override
  String getAvatarUrl() => userAvatar;

  @override
  String getMessage() => '$username saved a location to $bubbleName';

  @override
  String? getActionLabel() => 'View';

  @override
  bool hasAction() => true;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'friend_added_bubble',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'username': username,
      'userAvatar': userAvatar,
      'userId': userId,
      'bubbleName': bubbleName,
      'bubbleId': bubbleId,
      'locationName': locationName,
    };
  }

  @override
  String getNotificationTitle() => 'Bubble Activity';
}
