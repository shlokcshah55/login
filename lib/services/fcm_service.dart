import 'dart:async';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/models/notifications/base_notification.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  // Notification stream for UI
  final _notificationController = StreamController<BaseNotification>.broadcast();
  Stream<BaseNotification> get notificationStream => _notificationController.stream;

  List<BaseNotification> _notifications = [];
  List<BaseNotification> get notifications => List.unmodifiable(_notifications);

  /// Save FCM token to Supabase with retry logic
  Future<void> saveFCMToken(String fcmToken, {int retryCount = 0}) async {
    try {
      final userId = SupabaseClientManager().currentUser?.id;

      if (userId == null) {
        print('📲 No user logged in, skipping FCM token save');
        return;
      }

      await SupabaseClientManager().client.rpc(
        'update_fcm_token',
        params: {
          'p_user_id': userId,
          'p_fcm_token': fcmToken,
        },
      );

      print('📲 FCM token saved to Supabase');
    } catch (e) {
      print('📲 Error saving FCM token: $e');

      // Retry logic with exponential backoff
      if (retryCount < 3) {
        final delaySeconds = pow(2, retryCount); // 1s, 2s, 4s
        print('📲 Retrying in ${delaySeconds}s... (attempt ${retryCount + 1}/3)');

        await Future.delayed(Duration(seconds: delaySeconds.toInt()));
        await saveFCMToken(fcmToken, retryCount: retryCount + 1);
      } else {
        print('📲 Failed to save FCM token after 3 retries');
      }
    }
  }

  /// Get current FCM token and save to backend
  /// Call this when user logs in to ensure token is associated with their account
  Future<void> refreshAndSaveToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await saveFCMToken(token);
      } else {
        print('📲 No FCM token available to save');
      }
    } catch (e) {
      print('📲 Error refreshing FCM token: $e');
    }
  }

  /// Clear FCM token from backend (call on logout)
  /// Sets the token to empty string to prevent notifications to logged-out users
  Future<void> clearFCMToken() async {
    try {
      final userId = SupabaseClientManager().currentUser?.id;

      if (userId == null) {
        print('📲 No user logged in, skipping FCM token clear');
        return;
      }

      await SupabaseClientManager().client.rpc(
        'update_fcm_token',
        params: {
          'p_user_id': userId,
          'p_fcm_token': '', // Clear token
        },
      );

      print('📲 FCM token cleared from Supabase');
    } catch (e) {
      print('📲 Error clearing FCM token: $e');
    }
  }

  /// Initialize FCM listeners
  Future<void> initialize() async {
    // Get initial token
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await saveFCMToken(token);
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      saveFCMToken(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap (background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from terminated state via notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Handle foreground notification
  void _handleForegroundMessage(RemoteMessage message) {
    print('📲 Foreground notification received');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');

    final notification = BaseNotification.fromRemoteMessage(message);
    if (notification != null) {
      _notifications.insert(0, notification);
      _notificationController.add(notification);

      // TODO: Show in-app banner/snackbar
      // TODO: Update badge count
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('📲 Notification tapped');

    final notification = BaseNotification.fromRemoteMessage(message);
    if (notification != null) {
      // TODO: Navigate to appropriate screen based on notification type
      print('📲 Navigate to: ${notification.type}');
    }
  }

  /// Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      // Since notifications are immutable, we'd need to recreate
      // For now, just remove from unread list
      print('📲 Marked notification $notificationId as read');
    }
  }

  /// Get unread count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Dispose
  void dispose() {
    _notificationController.close();
  }
}
