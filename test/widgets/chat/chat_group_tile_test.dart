import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/bubble.dart';
import 'package:login/widgets/chat/chat_group_tile.dart';

void main() {
  testWidgets('unread bubbles show a new pill and filled chat CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatGroupTile(
            bubble: _bubble(unreadCount: 3),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('3 new'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
  });

  testWidgets('read bubbles keep the quieter default chat CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatGroupTile(
            bubble: _bubble(unreadCount: 0),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('new'), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_rounded), findsNothing);
  });
}

Bubble _bubble({required int unreadCount}) {
  return Bubble(
    id: 'bubble-1',
    name: 'Weekend Brunch',
    createdBy: 'owner-1',
    lastMessage: 'Let\'s lock the cafe',
    lastMessageTime: '2m',
    memberCount: 6,
    memberAvatars: const [],
    groupAvatar: '',
    unreadCount: unreadCount,
  );
}
