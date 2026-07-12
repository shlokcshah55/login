import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';

enum SocialShareNotificationOutcome { saved, needsChecking, failed }

class SocialPostReviewNotification extends BaseNotification {
  final String socialPostId;
  final String? platform;
  final int placeCount;
  final int savedCount;
  final String? firstPlaceName;
  final bool failed;
  final SocialShareNotificationOutcome outcome;
  final String title;
  final String body;

  SocialPostReviewNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.socialPostId,
    required this.platform,
    required this.placeCount,
    required this.savedCount,
    required this.firstPlaceName,
    required this.failed,
    required this.outcome,
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
    final rawSavedCount = data['savedCount'];
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

    final savedCount = _parseCount(rawSavedCount);
    final outcome = _parseOutcome(
      data['outcome']?.toString(),
      failed: failed,
      savedCount: savedCount,
    );

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
      savedCount: savedCount,
      firstPlaceName: _nonEmpty(data['firstPlaceName']),
      failed: failed,
      outcome: outcome,
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
  String? getActionLabel() => switch (outcome) {
        SocialShareNotificationOutcome.saved => 'View',
        SocialShareNotificationOutcome.needsChecking => 'Check',
        SocialShareNotificationOutcome.failed => 'Add place',
      };

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
      'savedCount': savedCount,
      if (firstPlaceName != null) 'firstPlaceName': firstPlaceName,
      'failed': failed,
      'outcome': switch (outcome) {
        SocialShareNotificationOutcome.saved => 'saved',
        SocialShareNotificationOutcome.needsChecking => 'needs_checking',
        SocialShareNotificationOutcome.failed => 'failed',
      },
      if (title.isNotEmpty) 'title': title,
      if (body.isNotEmpty) 'body': body,
    };
  }

  @override
  String getNotificationTitle() => title.isNotEmpty ? title : 'Ready to review';

  static int _parseCount(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String? _nonEmpty(dynamic raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  static SocialShareNotificationOutcome _parseOutcome(
    String? raw, {
    required bool failed,
    required int savedCount,
  }) {
    switch (raw?.trim().toLowerCase()) {
      case 'saved':
        return SocialShareNotificationOutcome.saved;
      case 'needs_checking':
      case 'needs-checking':
        return SocialShareNotificationOutcome.needsChecking;
      case 'failed':
        return SocialShareNotificationOutcome.failed;
    }
    if (failed) return SocialShareNotificationOutcome.failed;
    if (savedCount > 0) return SocialShareNotificationOutcome.saved;
    return SocialShareNotificationOutcome.needsChecking;
  }
}
