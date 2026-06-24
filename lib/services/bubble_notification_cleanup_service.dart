import 'package:flutter/services.dart';

class BubbleNotificationCleanupService {
  static const String channelName = 'com.example.srishlok.pinit/notifications';
  static const MethodChannel _channel = MethodChannel(channelName);

  const BubbleNotificationCleanupService();

  Future<void> clearBubbleNotifications(String bubbleId) async {
    final normalizedBubbleId = bubbleId.trim();
    if (normalizedBubbleId.isEmpty) return;

    try {
      await _channel.invokeMethod<int>(
        'clearBubbleNotifications',
        <String, String>{'bubbleId': normalizedBubbleId},
      );
    } on MissingPluginException {
      // Non-iOS platforms do not need this native cleanup.
    }
  }
}
