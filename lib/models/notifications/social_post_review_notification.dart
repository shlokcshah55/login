import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';

class SocialPostReviewNotification extends BaseNotification {
  final String socialPostId;
  final String? platform;
  final int placeCount;
  final bool failed;
  final String title;
  final String body;

  SocialPostReviewNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.socialPostId,
    required this.platform,
    required this.placeCount,
    required this.failed,
    required this.title,
    required this.body,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.socialPostReview,
        );

  /// Factory constructor from FCM data payload
  factory SocialPostReviewNotification.fromFCMData(Map<String, dynamic> data) {
    final rawSocialPostId = data['socialPostId'];
    final rawPlatform = data['platform'];
    final rawPlaceCount = data['placeCount'];
    final rawFailed = data['failed'];

    // placeCount may arrive as a string
    final int placeCount;
    if (rawPlaceCount is int) {
      placeCount = rawPlaceCount;
    } else if (rawPlaceCount is num) {
      placeCount = rawPlaceCount.toInt();
    } else {
      placeCount = int.tryParse(rawPlaceCount?.toString() ?? '') ?? 0;
    }

    // failed may arrive as 'true'/'false' string
    final bool failed;
    if (rawFailed is bool) {
      failed = rawFailed;
    } else {
      failed = rawFailed?.toString().toLowerCase() == 'true';
    }

    return SocialPostReviewNotification(
      id: data['id'].toString(),
      // Handle both String (FCM) and DateTime (DB)
      timestamp: data['timestamp'] is String
          ? DateTime.parse(data['timestamp'] as String)
          : data['timestamp'] as DateTime,
      // Handle both explicit false and missing field
      isRead: data['isRead'] == true || data['isRead'] == 'true',
      socialPostId: rawSocialPostId?.toString() ?? '',
      platform: rawPlatform?.toString(),
      placeCount: placeCount,
      failed: failed,
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
    );
  }

  @override
  String getAvatarUrl() => '';

  @override
  String getMessage() =>
      body.isNotEmpty ? body : 'Your shared post is ready to review';

  @override
  String? getActionLabel() => 'Review';

  @override
  bool hasAction() => socialPostId.isNotEmpty;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'social_post_review',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'socialPostId': socialPostId,
      if (platform != null && platform!.isNotEmpty) 'platform': platform,
      'placeCount': placeCount,
      'failed': failed,
      if (title.isNotEmpty) 'title': title,
      if (body.isNotEmpty) 'body': body,
    };
  }

  @override
  String getNotificationTitle() =>
      title.isNotEmpty ? title : 'Ready to review';
}
