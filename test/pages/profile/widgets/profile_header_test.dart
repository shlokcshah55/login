import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/profile/widgets/profile_header.dart';

void main() {
  testWidgets('exposes the rewards action in the profile header', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileHeader(
            user: UserModel(email: 'test@example.com', name: 'Taylor'),
            scrollOffset: 0,
            onNotificationsTap: () {},
            onRewardsTap: () => tapped = true,
            onSettingsTap: () {},
            unreadCount: 0,
            followersCount: 3,
            followingCount: 5,
            pinsCount: 8,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.card_giftcard_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.card_giftcard_rounded));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
