import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';

class VideoProcessedNotification extends BaseNotification {
  final String locationName;
  final String locationId;

  VideoProcessedNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.locationName,
    required this.locationId,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.videoProcessed,
        );

  /// Factory constructor from FCM data payload
  factory VideoProcessedNotification.fromFCMData(Map<String, dynamic> data) {
    return VideoProcessedNotification(
      id: data['id'] as String,
      timestamp: DateTime.parse(data['timestamp'] as String),
      isRead: false, // New notifications are always unread
      locationName: data['locationName'] as String,
      locationId: data['locationId'] as String,
    );
  }

  @override
  String getAvatarUrl() => 'lib/assets/default_avatar.png'; // App logo placeholder

  @override
  String getMessage() => 'We have saved $locationName from the shared TikTok';

  @override
  String? getActionLabel() => 'View';

  @override
  bool hasAction() => true;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'video_processed',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'locationName': locationName,
      'locationId': locationId,
    };
  }

  @override
  String getNotificationTitle() => 'Video Processed';
}
