import 'package:login/models/notification_type.dart';
import 'package:login/models/notifications/base_notification.dart';

class ProcessingErrorNotification extends BaseNotification {
  final String title;
  final String body;
  final String? errorType;
  final String? sourceUrl;
  final String? platform;

  ProcessingErrorNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.title,
    required this.body,
    required this.errorType,
    required this.sourceUrl,
    required this.platform,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.processingError,
        );

  factory ProcessingErrorNotification.fromFCMData(Map<String, dynamic> data) {
    final rawSourceUrl = data['sourceUrl'] ?? data['tiktokUrl'];

    return ProcessingErrorNotification(
      id: data['id'].toString(),
      timestamp: data['timestamp'] is String
          ? DateTime.parse(data['timestamp'] as String)
          : data['timestamp'] as DateTime,
      isRead: data['isRead'] == true || data['isRead'] == 'true',
      title: (data['title'] as String?) ?? 'Could not process video',
      body: (data['body'] as String?) ??
          'Something went wrong while processing your shared post.',
      errorType: data['errorType']?.toString(),
      sourceUrl: rawSourceUrl?.toString(),
      platform: data['platform']?.toString(),
    );
  }

  @override
  String getAvatarUrl() => '';

  @override
  String getMessage() => body;

  @override
  String? getActionLabel() => hasAction() ? 'Add manually' : null;

  @override
  bool hasAction() => true;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'processing_error',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'body': body,
      if (errorType != null && errorType!.isNotEmpty) 'errorType': errorType,
      if (sourceUrl != null && sourceUrl!.isNotEmpty) 'sourceUrl': sourceUrl,
      if (platform != null && platform!.isNotEmpty) 'platform': platform,
    };
  }

  @override
  String getNotificationTitle() => title;
}
