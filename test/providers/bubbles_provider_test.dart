import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/bubble.dart';
import 'package:login/providers/bubbles_provider.dart';
import 'package:login/supabase/helpers/bubbles.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  test('refresh preserves existing unread state when fetched bubble is stale',
      () async {
    final bubbleHelper = _MockBubbleHelper();
    final provider = BubblesProvider(
      userId: 'user-1',
      bubbleHelper: bubbleHelper,
    );

    when(() => bubbleHelper.getUserBubbles('user-1')).thenAnswer(
      (_) async => [
        _bubble(unreadCount: 3),
      ],
    );

    await provider.loadBubbles();

    expect(provider.bubbles.single.unreadCount, 3);

    when(() => bubbleHelper.getUserBubbles('user-1')).thenAnswer(
      (_) async => [
        _bubble(unreadCount: 0),
      ],
    );

    await provider.loadBubbles();

    expect(provider.bubbles.single.unreadCount, 3);
  });

  test('opening a bubble chat clears its unread state locally', () async {
    final bubbleHelper = _MockBubbleHelper();
    final provider = BubblesProvider(
      userId: 'user-1',
      bubbleHelper: bubbleHelper,
    );

    when(() => bubbleHelper.getUserBubbles('user-1')).thenAnswer(
      (_) async => [
        _bubble(unreadCount: 3),
      ],
    );

    await provider.loadBubbles();

    expect(provider.bubbles.single.unreadCount, 3);

    await (provider as dynamic).markBubbleReadLocally('bubble-1');

    expect(provider.bubbles.single.unreadCount, 0);
  });
}

class _MockBubbleHelper extends Mock implements BubbleHelper {}

Bubble _bubble({required int unreadCount}) {
  return Bubble(
    id: 'bubble-1',
    name: 'Weekend Brunch',
    createdBy: 'owner-1',
    lastMessage: 'Let\'s lock the cafe',
    lastMessageTime: '2m',
    lastActivityAt: DateTime.parse('2026-05-15T09:00:00Z'),
    memberCount: 6,
    memberAvatars: const [],
    groupAvatar: '',
    unreadCount: unreadCount,
  );
}
