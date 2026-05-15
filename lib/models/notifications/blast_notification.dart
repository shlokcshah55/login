import 'package:login/models/notification_type.dart';
import 'package:login/models/notifications/base_notification.dart';

class BlastNotification extends BaseNotification {
  final String title;
  final String body;

  BlastNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.title,
    required this.body,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.blast,
        );

  factory BlastNotification.fromFCMData(Map<String, dynamic> data) {
    return BlastNotification(
      id: data['id'] as String,
      timestamp: data['timestamp'] is String
          ? DateTime.parse(data['timestamp'] as String)
          : data['timestamp'] as DateTime,
      isRead: data['isRead'] == true || data['isRead'] == 'true',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
    );
  }

  @override
  String getAvatarUrl() => '';

  @override
  String getMessage() => body;

  @override
  String? getActionLabel() => null;

  @override
  bool hasAction() => false;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'blast',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'body': body,
    };
  }

  @override
  String getNotificationTitle() => title;
}
