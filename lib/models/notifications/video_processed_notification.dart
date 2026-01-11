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
      // Handle both String (FCM) and DateTime (DB)
      timestamp: data['timestamp'] is String
          ? DateTime.parse(data['timestamp'] as String)
          : data['timestamp'] as DateTime,
      // Handle both explicit false and missing field
      isRead: data['isRead'] == true || data['isRead'] == 'true',
      locationName: data['locationName'] as String,
      locationId: data['locationId'] as String,
    );
  }

  @override
  String getAvatarUrl() => 'lib/assets/restaurant_pin.png'; // App logo placeholder

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
