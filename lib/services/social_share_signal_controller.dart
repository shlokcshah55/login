import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notifications/social_post_review_notification.dart';

class SocialShareSignal {
  const SocialShareSignal({
    required this.notificationIds,
    required this.socialPostIds,
    required this.outcome,
    required this.title,
    required this.body,
    required this.autoDismiss,
  });

  final List<String> notificationIds;
  final List<String> socialPostIds;
  final SocialShareNotificationOutcome outcome;
  final String title;
  final String body;
  final bool autoDismiss;
}

class SocialShareSignalController {
  const SocialShareSignalController._();

  static SocialShareSignal? next(
    Iterable<BaseNotification> notifications, {
    required Set<String> presentedIds,
    bool aggregate = false,
  }) {
    final unseen = notifications
        .whereType<SocialPostReviewNotification>()
        .where((notification) => !presentedIds.contains(notification.id))
        .toList(growable: false);
    if (unseen.isEmpty) return null;

    if (!aggregate || unseen.length == 1) {
      final notification = unseen.first;
      return SocialShareSignal(
        notificationIds: [notification.id],
        socialPostIds: [notification.socialPostId],
        outcome: notification.outcome,
        title: notification.getNotificationTitle(),
        body: notification.getNotificationBody(),
        autoDismiss: true,
      );
    }

    final allTikTok = unseen.every(
      (notification) => notification.platform?.toLowerCase() != 'instagram',
    );
    final allReels = unseen.every(
      (notification) => notification.platform?.toLowerCase() == 'instagram',
    );
    final noun = allTikTok
        ? 'TikToks'
        : allReels
            ? 'Reels'
            : 'shared posts';
    final outcome = unseen.any(
      (notification) =>
          notification.outcome == SocialShareNotificationOutcome.failed,
    )
        ? SocialShareNotificationOutcome.failed
        : unseen.any(
            (notification) =>
                notification.outcome ==
                SocialShareNotificationOutcome.needsChecking,
          )
            ? SocialShareNotificationOutcome.needsChecking
            : SocialShareNotificationOutcome.saved;
    return SocialShareSignal(
      notificationIds: unseen.map((notification) => notification.id).toList(),
      socialPostIds:
          unseen.map((notification) => notification.socialPostId).toList(),
      outcome: outcome,
      title: 'Processed ${unseen.length} $noun',
      body: 'Review them here.',
      autoDismiss: true,
    );
  }
}
