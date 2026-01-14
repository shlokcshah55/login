import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';

class FriendVisitedLocationNotification extends BaseNotification {
  final String username;
  final String userAvatar;
  final String userId;
  final String locationName;
  final String locationId;

  FriendVisitedLocationNotification({
    required String id,
    required DateTime timestamp,
    required bool isRead,
    required this.username,
    required this.userAvatar,
    required this.userId,
    required this.locationName,
    required this.locationId,
  }) : super(
          id: id,
          timestamp: timestamp,
          isRead: isRead,
          type: NotificationType.friendVisitedLocation,
        );

  /// Factory constructor from FCM data payload
  factory FriendVisitedLocationNotification.fromFCMData(Map<String, dynamic> data) {
    return FriendVisitedLocationNotification(
      id: data['id'] as String,
      // Handle both String (FCM) and DateTime (DB)
      timestamp: data['timestamp'] is String
          ? DateTime.parse(data['timestamp'] as String)
          : data['timestamp'] as DateTime,
      // Handle both explicit false and missing field
      isRead: data['isRead'] == true || data['isRead'] == 'true',
      username: data['username'] as String,
      userAvatar: data['userAvatar'] as String,
      userId: data['userId'] as String,
      locationName: data['locationName'] as String,
      locationId: data['locationId'] as String,
    );
  }

  @override
  String getAvatarUrl() => userAvatar;

  @override
  String getMessage() => '$username went to $locationName';

  @override
  String? getActionLabel() => 'View';

  @override
  bool hasAction() => true;

  @override
  Map<String, dynamic> toFCMData() {
    return {
      'type': 'friend_visited_location',
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'username': username,
      'userAvatar': userAvatar,
      'userId': userId,
      'locationName': locationName,
      'locationId': locationId,
    };
  }

  @override
  String getNotificationTitle() => 'Friend Activity';
}
