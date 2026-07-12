import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notifications/social_post_review_notification.dart';
import 'package:login/services/social_share_presentation_store.dart';
import 'package:login/services/social_share_signal_controller.dart';
import 'package:login/widgets/social_share_signal_host.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SocialPostReviewNotification notification(
    SocialShareNotificationOutcome outcome, {
    String? id,
    String title = 'Saved from TikTok',
    String body = 'Noodle Yard is ready.',
  }) {
    return SocialPostReviewNotification(
      id: id ?? 'notification-${outcome.name}',
      timestamp: DateTime.utc(2026, 7, 11),
      isRead: false,
      socialPostId: 'post-1',
      platform: 'tiktok',
      placeCount: 1,
      savedCount: outcome == SocialShareNotificationOutcome.saved ? 1 : 0,
      firstPlaceName: 'Noodle Yard',
      failed: outcome == SocialShareNotificationOutcome.failed,
      outcome: outcome,
      title: outcome == SocialShareNotificationOutcome.saved
          ? title
          : 'Check this TikTok',
      body: body,
    );
  }

  Widget subject({
    required List<BaseNotification> notifications,
    required List<String> readIds,
    ValueChanged<SocialShareSignal>? onOpen,
    Stream<BaseNotification> notificationStream = const Stream.empty(),
    ValueNotifier<bool>? notificationsVisible,
  }) {
    return MaterialApp(
      home: SocialShareSignalHost(
        notificationSource: () => notifications,
        notificationStream: notificationStream,
        userIdSource: () => 'user-1',
        presentationStore: SocialSharePresentationStore(),
        markRead: (id) async => readIds.add(id),
        notificationsVisible: notificationsVisible,
        onOpenSignal: onOpen,
        child: const Scaffold(body: Text('Home')),
      ),
    );
  }

  Widget builderSubject({
    required List<BaseNotification> notifications,
  }) {
    return MaterialApp(
      builder: (context, child) => SocialShareSignalHost(
        notificationSource: () => notifications,
        notificationStream: const Stream.empty(),
        userIdSource: () => 'user-1',
        presentationStore: SocialSharePresentationStore(),
        markRead: (_) async {},
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Text('Home')),
    );
  }

  testWidgets('banner auto-dismisses without marking notification read',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final readIds = <String>[];
    await tester.pumpWidget(
      subject(
        notifications: [notification(SocialShareNotificationOutcome.saved)],
        readIds: readIds,
      ),
    );
    await tester.pump();

    expect(find.text('Saved from TikTok'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Saved from TikTok'), findsNothing);
    expect(readIds, isEmpty);
  });

  testWidgets('attention banner also auto-dismisses', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final readIds = <String>[];
    await tester.pumpWidget(
      subject(
        notifications: [
          notification(SocialShareNotificationOutcome.needsChecking),
        ],
        readIds: readIds,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Check this TikTok'), findsNothing);
    expect(readIds, isEmpty);
  });

  testWidgets('tapping signal opens its destination', (tester) async {
    SharedPreferences.setMockInitialValues({});
    SocialShareSignal? opened;
    await tester.pumpWidget(
      subject(
        notifications: [notification(SocialShareNotificationOutcome.saved)],
        readIds: [],
        onOpen: (signal) => opened = signal,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Saved from TikTok'));
    await tester.pumpAndSettle();

    expect(opened?.socialPostIds, ['post-1']);
    expect(find.text('Saved from TikTok'), findsNothing);
  });

  testWidgets('tapping banner does not mark the notification read',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final readIds = <String>[];
    await tester.pumpWidget(
      subject(
        notifications: [notification(SocialShareNotificationOutcome.saved)],
        readIds: readIds,
        onOpen: (_) {},
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Saved from TikTok'));
    await tester.pumpAndSettle();

    expect(readIds, isEmpty);
  });

  testWidgets('tapping banner opens the standard Notifications page',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      subject(
        notifications: [notification(SocialShareNotificationOutcome.saved)],
        readIds: [],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Saved from TikTok'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Saved from TikTok'), findsNothing);
  });

  testWidgets('startup aggregates multiple TikToks into review copy',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notifications = <BaseNotification>[
      notification(SocialShareNotificationOutcome.saved, id: 'one'),
      notification(SocialShareNotificationOutcome.saved, id: 'two'),
    ];
    await tester.pumpWidget(
      subject(notifications: notifications, readIds: []),
    );
    await tester.pump();

    expect(find.text('Processed 2 TikToks'), findsOneWidget);
    expect(find.text('Review them here.'), findsOneWidget);
  });

  testWidgets('suppresses banner while Notifications is visible',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final visible = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      subject(
        notifications: [notification(SocialShareNotificationOutcome.saved)],
        readIds: [],
        notificationsVisible: visible,
      ),
    );
    await tester.pump();

    expect(find.text('Saved from TikTok'), findsNothing);
    final presented =
        await SocialSharePresentationStore().presentedIds('user-1');
    expect(presented, contains('notification-saved'));
    visible.dispose();
  });

  testWidgets('queues arrivals received while a banner is visible',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notifications = <BaseNotification>[
      notification(SocialShareNotificationOutcome.saved, id: 'one'),
    ];
    final stream = StreamController<BaseNotification>.broadcast();
    await tester.pumpWidget(
      subject(
        notifications: notifications,
        readIds: [],
        notificationStream: stream.stream,
      ),
    );
    await tester.pump();
    expect(find.text('Saved from TikTok'), findsOneWidget);

    final second = notification(
      SocialShareNotificationOutcome.saved,
      id: 'two',
      title: 'Another TikTok finished',
    );
    notifications.add(second);
    stream.add(second);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dismiss-social-share-signal')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Another TikTok finished'), findsOneWidget);
    await stream.close();
  });

  testWidgets('positions the banner at the top safe area', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      subject(
        notifications: [notification(SocialShareNotificationOutcome.saved)],
        readIds: [],
      ),
    );
    await tester.pump();

    final top = tester.getTopLeft(
      find.byKey(const ValueKey('social-share-notification-banner')),
    );
    expect(top.dy, lessThan(80));
  });

  testWidgets('renders when hosted by MaterialApp builder', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      builderSubject(
        notifications: [notification(SocialShareNotificationOutcome.saved)],
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Saved from TikTok'), findsOneWidget);
  });
}
