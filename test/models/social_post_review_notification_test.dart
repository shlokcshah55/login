import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/notifications/social_post_review_notification.dart';

void main() {
  Map<String, dynamic> data({
    String? outcome,
    int savedCount = 0,
    int placeCount = 1,
    bool failed = false,
  }) {
    return {
      'id': 'notification-1',
      'timestamp': DateTime.utc(2026, 7, 11).toIso8601String(),
      'socialPostId': 'post-1',
      'platform': 'tiktok',
      'placeCount': '$placeCount',
      'savedCount': '$savedCount',
      'firstPlaceName': 'Noodle Yard',
      'failed': '$failed',
      if (outcome != null) 'outcome': outcome,
      'title': 'Saved from TikTok',
      'body': 'Noodle Yard was added to your saves.',
    };
  }

  test('parses explicit saved outcome and metadata', () {
    final notification = SocialPostReviewNotification.fromFCMData(
        data(outcome: 'saved', savedCount: 1));

    expect(notification.outcome, SocialShareNotificationOutcome.saved);
    expect(notification.savedCount, 1);
    expect(notification.firstPlaceName, 'Noodle Yard');
    expect(notification.getActionLabel(), 'View');
  });

  test('parses needs-checking and failed contextual actions', () {
    final checking = SocialPostReviewNotification.fromFCMData(
      data(outcome: 'needs_checking'),
    );
    final failed = SocialPostReviewNotification.fromFCMData(
      data(outcome: 'failed', failed: true, placeCount: 0),
    );

    expect(checking.outcome, SocialShareNotificationOutcome.needsChecking);
    expect(checking.getActionLabel(), 'Check');
    expect(failed.outcome, SocialShareNotificationOutcome.failed);
    expect(failed.getActionLabel(), 'Add place');
  });

  test('derives outcome for older payloads without outcome', () {
    final saved = SocialPostReviewNotification.fromFCMData(data(savedCount: 2));
    final checking = SocialPostReviewNotification.fromFCMData(data());

    expect(saved.outcome, SocialShareNotificationOutcome.saved);
    expect(checking.outcome, SocialShareNotificationOutcome.needsChecking);
  });

  test('serializes outcome and save metadata', () {
    final notification = SocialPostReviewNotification.fromFCMData(
        data(outcome: 'saved', savedCount: 1));

    expect(notification.toFCMData(), containsPair('outcome', 'saved'));
    expect(notification.toFCMData(), containsPair('savedCount', 1));
    expect(
      notification.toFCMData(),
      containsPair('firstPlaceName', 'Noodle Yard'),
    );
  });
}
