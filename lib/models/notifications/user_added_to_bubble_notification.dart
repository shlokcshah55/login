import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';

class UserAddedToBubbleNotification extends BaseNotification {
  final String inviterUsername;
  final String inviterAvatar;
  final String inviterId;
  final String bubbleName;
  final String bubbleId;

  UserAddedToBubbleNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.inviterUsername,
    required this.inviterAvatar,
    required this.inviterId,
    required this.bubbleName,
    required this.bubbleId,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.userAddedToBubble,
        );

  /// Factory constructor from FCM data payload
  factory UserAddedToBubbleNotification.fromFCMData(Map<String, dynamic> data) {
    return UserAddedToBubbleNotification(
      id: data['id'] as String,
      // Handle both String (FCM) and DateTime (DB)
      timestamp: data['timestamp'] is String
          ? DateTime.parse(data['timestamp'] as String)
          : data['timestamp'] as DateTime,
      // Handle both explicit false and missing field
      isRead: data['isRead'] == true || data['isRead'] == 'true',
      inviterUsername: data['inviterUsername'] as String,
      inviterAvatar: data['inviterAvatar'] as String,
      inviterId: data['inviterId'] as String,
      bubbleName: data['bubbleName'] as String,
      bubbleId: data['bubbleId'] as String,
    );
  }

  @override
  String getAvatarUrl() => inviterAvatar;

  @override
  String getMessage() => '$inviterUsername added you to $bubbleName';

  @override
  String? getActionLabel() => 'View Bubble';

  @override
  bool hasAction() => true;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'user_added_to_bubble',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'inviterUsername': inviterUsername,
      'inviterAvatar': inviterAvatar,
      'inviterId': inviterId,
      'bubbleName': bubbleName,
      'bubbleId': bubbleId,
    };
  }

  @override
  String getNotificationTitle() => 'New Bubble Invitation';
}
