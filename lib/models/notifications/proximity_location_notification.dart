import 'package:login/models/notification_type.dart';
import 'package:login/models/notifications/base_notification.dart';

class ProximityLocationNotification extends BaseNotification {
  final String locationId;
  final String locationName;
  final int? distanceMeters;

  /// Copy the server sent with the push. Null for older notifications, which
  /// fall back to a generic line built from the fields above.
  final String? title;
  final String? body;
  final String? creatorHandle;
  final String? dish;
  final String? savedMethod;

  ProximityLocationNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.locationId,
    required this.locationName,
    required this.distanceMeters,
    this.title,
    this.body,
    this.creatorHandle,
    this.dish,
    this.savedMethod,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.proximityLocation,
        );

  factory ProximityLocationNotification.fromFCMData(Map<String, dynamic> data) {
    final rawDistance = data['distanceMeters'];
    String? text(String key) {
      final value = data[key]?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    return ProximityLocationNotification(
      id: data['id'] as String,
      timestamp: data['timestamp'] is String
          ? DateTime.parse(data['timestamp'] as String)
          : data['timestamp'] as DateTime,
      isRead: data['isRead'] == true || data['isRead'] == 'true',
      locationId: data['locationId'] as String,
      locationName: data['locationName'] as String,
      distanceMeters: rawDistance is num
          ? rawDistance.toInt()
          : int.tryParse(rawDistance?.toString() ?? ''),
      title: text('title'),
      body: text('body'),
      creatorHandle: text('creatorHandle'),
      dish: text('dish'),
      savedMethod: text('savedMethod'),
    );
  }

  @override
  String getAvatarUrl() => '';

  @override
  String getMessage() {
    if (body != null) return body!;
    if (distanceMeters == null) {
      return '$locationName is within walking distance';
    }

    return '$locationName is ${distanceMeters}m away';
  }

  @override
  String? getActionLabel() => 'View';

  @override
  bool hasAction() => true;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'proximity_location',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'locationId': locationId,
      'locationName': locationName,
      if (distanceMeters != null) 'distanceMeters': distanceMeters.toString(),
    };
  }

  @override
  String getNotificationTitle() => title ?? 'Saved place nearby';
}
