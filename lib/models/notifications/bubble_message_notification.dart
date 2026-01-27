import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';

class BubbleMessageNotification extends BaseNotification {
  final String senderUsername;
  final String senderAvatar;
  final String bubbleName;
  final String bubbleId;
  final String messagePreview;

  BubbleMessageNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.senderUsername,
    required this.senderAvatar,
    required this.bubbleName,
    required this.bubbleId,
    required this.messagePreview,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.newMessage,
        );

  /// Factory constructor from FCM data payload
  factory BubbleMessageNotification.fromFCMData(Map<String, dynamic> data) {
    return BubbleMessageNotification(
      id: data['id'] as String,
      // Handle both String (FCM) and DateTime (DB)
      timestamp: data['timestamp'] is String
          ? DateTime.parse(data['timestamp'] as String)
          : data['timestamp'] as DateTime,
      // Handle both explicit false and missing field
      isRead: data['isRead'] == true || data['isRead'] == 'true',
      senderUsername: data['senderUsername'] as String,
      senderAvatar: data['senderAvatar'] as String,
      bubbleName: data['bubbleName'] as String,
      bubbleId: data['bubbleId'] as String,
      messagePreview: data['messagePreview'] as String,
    );
  }

  @override
  String getAvatarUrl() => senderAvatar;

  @override
  String getMessage() => '$senderUsername in $bubbleName: $messagePreview';

  @override
  String? getActionLabel() => 'View';

  @override
  bool hasAction() => true;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'new_message',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'senderUsername': senderUsername,
      'senderAvatar': senderAvatar,
      'bubbleName': bubbleName,
      'bubbleId': bubbleId,
      'messagePreview': messagePreview,
    };
  }

  @override
  String getNotificationTitle() => 'New Message';
}
