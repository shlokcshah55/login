import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/bubble_notification_cleanup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(BubbleNotificationCleanupService.channelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('clearBubbleNotifications forwards the bubble id to native iOS cleanup',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 2;
    });

    await const BubbleNotificationCleanupService()
        .clearBubbleNotifications(' bubble-1 ');

    expect(calls, hasLength(1));
    expect(calls.single.method, 'clearBubbleNotifications');
    expect(calls.single.arguments, {'bubbleId': 'bubble-1'});
  });

  test('clearBubbleNotifications ignores blank bubble ids', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 0;
    });

    await const BubbleNotificationCleanupService().clearBubbleNotifications('');

    expect(calls, isEmpty);
  });
}
