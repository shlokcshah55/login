import 'package:login/models/notification_type.dart';
import 'package:login/models/notifications/base_notification.dart';

class NotesImportCompleteNotification extends BaseNotification {
  final String title;
  final String body;
  final int processedCount;
  final int savedCount;
  final String? sourceName;

  NotesImportCompleteNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.title,
    required this.body,
    required this.processedCount,
    required this.savedCount,
    required this.sourceName,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.notesImportComplete,
        );

  factory NotesImportCompleteNotification.fromFCMData(
    Map<String, dynamic> data,
  ) {
    final rawProcessedCount = data['processedCount'];
    final rawSavedCount = data['savedCount'];

    return NotesImportCompleteNotification(
      id: data['id'] as String,
      timestamp: data['timestamp'] is String
          ? DateTime.parse(data['timestamp'] as String)
          : data['timestamp'] as DateTime,
      isRead: data['isRead'] == true || data['isRead'] == 'true',
      title: (data['title'] as String?) ?? 'Import complete',
      body: (data['body'] as String?) ?? 'Your note import has finished.',
      processedCount: rawProcessedCount is num
          ? rawProcessedCount.toInt()
          : int.tryParse(rawProcessedCount?.toString() ?? '') ?? 0,
      savedCount: rawSavedCount is num
          ? rawSavedCount.toInt()
          : int.tryParse(rawSavedCount?.toString() ?? '') ?? 0,
      sourceName: data['sourceName'] as String?,
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
      'type': 'notes_import_complete',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'body': body,
      'processedCount': processedCount.toString(),
      'savedCount': savedCount.toString(),
      if (sourceName != null && sourceName!.isNotEmpty)
        'sourceName': sourceName,
    };
  }

  @override
  String getNotificationTitle() => title;
}
