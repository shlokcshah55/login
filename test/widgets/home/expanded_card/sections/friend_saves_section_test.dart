import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/proximal_models.dart';
import 'package:login/widgets/home/expanded_card/sections/friend_saves_section.dart';

void main() {
  testWidgets('shows friend saves with shared match score', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FriendSavesSection(
            friendSaves: [
              FriendSave(
                friendId: 'friend-1',
                friendName: 'Maya Patel',
                friendUsername: 'maya',
                actionType: 'save',
                timestamp: '2026-06-08T12:00:00Z',
              ),
              FriendSave(
                friendId: 'friend-2',
                friendName: 'Leo Shah',
                actionType: 'save',
                timestamp: '2026-06-08T13:00:00Z',
              ),
            ],
            matchScore: 0.84,
          ),
        ),
      ),
    );

    expect(find.text('Saved by friends'), findsOneWidget);
    expect(find.text('Maya Patel'), findsOneWidget);
    expect(find.text('@maya'), findsOneWidget);
    expect(find.text('Leo Shah'), findsOneWidget);
    expect(find.text('You + Maya match 84% here'), findsOneWidget);
    expect(find.text('You + Leo match 84% here'), findsOneWidget);
  });

  testWidgets('renders nothing without friend saves', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FriendSavesSection(
            friendSaves: [],
            matchScore: 0.84,
          ),
        ),
      ),
    );

    expect(find.byType(FriendSavesSection), findsOneWidget);
    expect(find.text('Saved by friends'), findsNothing);
  });
}
