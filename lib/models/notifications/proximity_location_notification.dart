import 'package:login/models/notification_type.dart';
import 'package:login/models/notifications/base_notification.dart';

class ProximityLocationNotification extends BaseNotification {
  final String locationId;
  final String locationName;
  final int? distanceMeters;

  ProximityLocationNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.locationId,
    required this.locationName,
    required this.distanceMeters,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.proximityLocation,
        );

  factory ProximityLocationNotification.fromFCMData(Map<String, dynamic> data) {
    final rawDistance = data['distanceMeters'];

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
    );
  }

  @override
  String getAvatarUrl() => '';

  @override
  String getMessage() {
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
  String getNotificationTitle() => 'Saved place nearby';
}
