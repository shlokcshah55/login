import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/message.dart';
import 'package:login/providers/messaging_provider.dart';
import 'package:login/supabase/helpers/messaging.dart';
import 'package:login/supabase/helpers/notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('initialize marks the bubble as read and clears related notifications',
      () async {
    final messagingHelper = _FakeMessagingHelper();
    final notificationsHelper = _FakeNotificationsHelper();
    final provider = MessagingProvider(
      bubbleId: 'bubble-1',
      messagingHelper: messagingHelper,
      notificationsHelper: notificationsHelper,
    );

    await provider.initialize();

    expect(messagingHelper.markedReadBubbleIds, ['bubble-1']);
    expect(notificationsHelper.clearedBubbleIds, ['bubble-1']);
  });
}

class _FakeMessagingHelper implements MessagingHelper {
  final List<String> markedReadBubbleIds = <String>[];

  @override
  Future<void> initializeBubbleChat(String bubbleId) async {}

  @override
  Future<String?> sendMessage({
    required String bubbleId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
    String? repliedToMessageId,
    int? locationId,
  }) async => null;

  @override
  Future<List<MessageModel>> getBubbleMessages({
    required String bubbleId,
    int limit = 50,
    DateTime? beforeTimestamp,
  }) async => const [];

  @override
  void subscribeToMessages(
    String bubbleId,
    void Function(PostgresChangePayload payload) onEvent,
  ) {}

  @override
  Future<void> markBubbleRead(String bubbleId) async {
    markedReadBubbleIds.add(bubbleId);
  }

  @override
  Future<bool> setMessageLiked({
    required String messageId,
    required bool liked,
  }) async => liked;

  @override
  Future<int> getUnreadCount(String bubbleId) async => 0;

  @override
  Future<int> getMessageCount(String bubbleId) async => 0;

  @override
  void unsubscribeFromMessages() {}
}

class _FakeNotificationsHelper implements NotificationsHelper {
  final List<String> clearedBubbleIds = <String>[];

  @override
  Future<int> markBubbleMessageNotificationsAsRead(String bubbleId) async {
    clearedBubbleIds.add(bubbleId);
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
