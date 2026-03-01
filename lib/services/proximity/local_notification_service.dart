import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin singleton wrapper around FlutterLocalNotificationsPlugin
/// for showing proximity notifications.
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(iOS: darwinSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> showProximityNotification({
    required int locationId,
    required String locationName,
  }) async {
    if (!_initialized) await initialize();

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(iOS: darwinDetails);

    await _plugin.show(
      locationId, // use locationId as notification ID for dedup
      "You're near $locationName",
      'Check it out while you\'re nearby!',
      details,
    );
  }
}
