import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/users.dart';
import 'package:login/widgets/chat/add_members_dialog.dart';

void main() {
  test('filterAddableBubbleFriends removes existing members and null ids', () {
    final filteredFriends = filterAddableBubbleFriends(
      friends: [
        UserModel(
          supabaseId: 'eligible-user',
          email: 'eligible@example.com',
          name: 'Eligible User',
        ),
        UserModel(
          supabaseId: 'existing-member',
          email: 'member@example.com',
          name: 'Existing Member',
        ),
        UserModel(
          email: 'missing-id@example.com',
          name: 'Missing Id',
        ),
      ],
      existingMemberIds: {'existing-member'},
    );

    expect(
        filteredFriends.map((friend) => friend.supabaseId), ['eligible-user']);
  });

  test(
      'filterAddableBubbleFriends searches only within the allowed friends list',
      () {
    final filteredFriends = filterAddableBubbleFriends(
      friends: [
        UserModel(
          supabaseId: 'name-match',
          email: 'alpha@example.com',
          name: 'Alicia Stone',
          username: 'alicia',
        ),
        UserModel(
          supabaseId: 'username-match',
          email: 'beta@example.com',
          name: 'Beatrice',
          username: 'ally-cat',
        ),
        UserModel(
          supabaseId: 'email-match',
          email: 'friend.charlie@example.com',
          name: 'Charlie',
          username: 'charlie',
        ),
      ],
      existingMemberIds: const {},
      query: 'ali',
    );

    expect(
      filteredFriends.map((friend) => friend.supabaseId),
      ['name-match'],
    );
  });
}
