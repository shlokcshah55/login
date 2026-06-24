import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/message.dart';
import 'package:login/providers/messaging_provider.dart';
import 'package:login/services/bubble_notification_cleanup_service.dart';
import 'package:login/supabase/helpers/messaging.dart';
import 'package:login/supabase/helpers/notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(BubbleNotificationCleanupService.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('initialize clears delivered notifications for the opened bubble',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 3;
    });

    final provider = MessagingProvider(
      bubbleId: 'bubble-1',
      messagingHelper: _FakeMessagingHelper(),
      notificationsHelper: _FakeNotificationsHelper(),
    );

    await provider.initialize();

    final cleanupCall = calls.singleWhere(
      (call) => call.method == 'clearBubbleNotifications',
    );
    expect(
      (cleanupCall.arguments as Map<Object?, Object?>)['bubbleId'],
      'bubble-1',
    );

    provider.dispose();
  });
}

class _FakeMessagingHelper implements MessagingHelper {
  @override
  Future<void> initializeBubbleChat(String bubbleId) async {}

  @override
  Future<List<MessageModel>> getBubbleMessages({
    required String bubbleId,
    int limit = 50,
    DateTime? beforeTimestamp,
  }) async =>
      const [];

  @override
  Future<void> markBubbleRead(String bubbleId) async {}

  @override
  void subscribeToMessages(
    String bubbleId,
    void Function(PostgresChangePayload) onEvent,
  ) {}

  @override
  void unsubscribeFromMessages() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNotificationsHelper implements NotificationsHelper {
  @override
  Future<int> markBubbleMessageNotificationsAsRead(String bubbleId) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
