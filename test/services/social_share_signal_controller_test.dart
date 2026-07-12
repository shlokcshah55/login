import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/notifications/social_post_review_notification.dart';
import 'package:login/services/social_share_signal_controller.dart';

void main() {
  SocialPostReviewNotification notification({
    required String id,
    required SocialShareNotificationOutcome outcome,
    int savedCount = 1,
    String platform = 'tiktok',
  }) {
    return SocialPostReviewNotification(
      id: id,
      timestamp: DateTime.utc(2026, 7, 11),
      isRead: false,
      socialPostId: 'post-$id',
      platform: platform,
      placeCount: savedCount,
      savedCount: savedCount,
      firstPlaceName: 'Noodle Yard',
      failed: outcome == SocialShareNotificationOutcome.failed,
      outcome: outcome,
      title: outcome == SocialShareNotificationOutcome.saved
          ? 'Saved from TikTok'
          : 'Check this share',
      body: 'Noodle Yard was added to your saves.',
    );
  }

  test('aggregates unseen startup notifications with review copy', () {
    final signal = SocialShareSignalController.next(
      [
        notification(id: '1', outcome: SocialShareNotificationOutcome.saved),
        notification(
          id: '2',
          outcome: SocialShareNotificationOutcome.saved,
          savedCount: 2,
        ),
      ],
      presentedIds: const {},
      aggregate: true,
    );

    expect(signal?.notificationIds, ['1', '2']);
    expect(signal?.title, 'Processed 2 TikToks');
    expect(signal?.body, 'Review them here.');
    expect(signal?.autoDismiss, isTrue);
  });

  test('foreground selection preserves the first notification message', () {
    final signal = SocialShareSignalController.next(
      [
        notification(id: '1', outcome: SocialShareNotificationOutcome.saved),
        notification(
          id: '2',
          outcome: SocialShareNotificationOutcome.needsChecking,
        ),
      ],
      presentedIds: const {},
    );

    expect(signal?.notificationIds, ['1']);
    expect(signal?.title, 'Saved from TikTok');
    expect(signal?.body, 'Noodle Yard was added to your saves.');
    expect(signal?.autoDismiss, isTrue);
  });

  test('attention notifications also auto-dismiss as banners', () {
    final signal = SocialShareSignalController.next(
      [
        notification(
          id: '1',
          outcome: SocialShareNotificationOutcome.needsChecking,
        ),
      ],
      presentedIds: const {},
    );

    expect(signal?.autoDismiss, isTrue);
  });

  test('excludes notifications already presented', () {
    final signal = SocialShareSignalController.next(
      [notification(id: '1', outcome: SocialShareNotificationOutcome.saved)],
      presentedIds: const {'1'},
    );

    expect(signal, isNull);
  });
}
