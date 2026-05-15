import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/actions.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/chat/expanded_bubble_view.dart';

void main() {
  testWidgets('tapping recent activity opens the activity sheet', (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpandedChatView(
          bubble: _bubble(),
          onClose: () {},
          initialUnreadCount: 2,
          initialActivities: [_activity()],
          onShowActivity: () {
            opened = true;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('expanded_bubble_recent_activity')));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
  });

  testWidgets('tapping top pins opens the pins chat tab', (tester) async {
    var openedPins = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpandedChatView(
          bubble: _bubble(),
          onClose: () {},
          initialUnreadCount: 2,
          initialActivities: const [],
          onOpenPinsChat: () async {
            openedPins = true;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('expanded_bubble_top_pins')));
    await tester.pumpAndSettle();

    expect(openedPins, isTrue);
  });

  testWidgets('tapping the pins stat opens the pins chat tab', (tester) async {
    var openedPins = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpandedChatView(
          bubble: _bubble(),
          onClose: () {},
          initialUnreadCount: 2,
          initialActivities: const [],
          onOpenPinsChat: () async {
            openedPins = true;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('expanded_bubble_pins_stat')));
    await tester.pumpAndSettle();

    expect(openedPins, isTrue);
  });

  testWidgets('tapping a member avatar opens that user profile', (tester) async {
    String? openedUserId;

    await tester.pumpWidget(
      MaterialApp(
        home: ExpandedChatView(
          bubble: _bubble(),
          onClose: () {},
          initialUnreadCount: 2,
          initialActivities: const [],
          onOpenUserProfile: (userId) async {
            openedUserId = userId;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('expanded_bubble_members_stat')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('expanded_bubble_member_user-2')),
    );
    await tester.tap(find.byKey(const Key('expanded_bubble_member_user-2')));
    await tester.pumpAndSettle();

    expect(openedUserId, 'user-2');
  });
}

Bubble _bubble() {
  return Bubble(
    id: 'bubble-1',
    name: 'Weekend Plans',
    createdBy: 'user-1',
    lastMessage: 'Pinned it',
    lastMessageTime: 'now',
    memberCount: 3,
    memberAvatars: const ['', '', ''],
    groupAvatar: '',
    memberIds: const ['user-1', 'user-2', 'user-3'],
    memberNames: const ['Alex', 'Sam', 'Taylor'],
    groupLocations: [
      LocationModel(
        locationId: 1,
        name: 'Cafe Lune',
        createdAt: DateTime(2026, 5, 14),
        imageUrl: '',
      ),
    ],
  );
}

UserLocationActionModel _activity() {
  return UserLocationActionModel(
    userId: 'user-2',
    locationId: 1,
    action: 'save',
    createdAt: DateTime(2026, 5, 14),
    name: 'Sam',
    user_avatar_url: '',
    locationName: 'Cafe Lune',
  );
}
