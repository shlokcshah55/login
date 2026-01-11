import 'dart:async';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/supabase/helpers/notifications.dart';
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

  late final NotificationsHelper _notificationsHelper;
  RealtimeChannel? _realtimeChannel;

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
    print('📲 Initializing FCM Service');

    // Initialize notifications helper
    _notificationsHelper = NotificationsHelper();

    // Check if user is already logged in (restored session)
    final isLoggedIn = SupabaseClientManager().currentUser != null;

    if (isLoggedIn) {
      print('📲 User already logged in, loading notifications');
      // Fetch notifications from DB on startup
      await _loadNotificationsFromDB();

      // Setup Realtime subscription for new notifications
      _setupRealtimeSubscription();
    } else {
      print('📲 User not logged in, skipping notification load');
    }

    // Get initial token
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await saveFCMToken(token);
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      saveFCMToken(newToken);
    });

    // Handle foreground messages - save to DB instead of memory
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap (background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from terminated state via notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    print('📲 FCM Service initialization complete');
  }

  /// Handle foreground notification
  void _handleForegroundMessage(RemoteMessage message) async {
    print('📲 Foreground notification received');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');

    final notification = BaseNotification.fromRemoteMessage(message);
    if (notification != null) {
      // Save to database first
      try {
        await _notificationsHelper.saveNotification(notification);

        // Reload from DB to get the saved version
        await _loadNotificationsFromDB();

        // TODO: Show in-app banner/snackbar
        // TODO: Update badge count
      } catch (e) {
        print('📲 Error saving notification to DB: $e');

        // Fallback: add to memory if DB fails
        _notifications.insert(0, notification);
        _notificationController.add(notification);
      }
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
  Future<void> markAsRead(String notificationId) async {
    try {
      // Update in database
      await _notificationsHelper.markAsRead(notificationId);

      // Reload from DB to refresh local state
      await _loadNotificationsFromDB();

      print('📲 Marked notification $notificationId as read');
    } catch (e) {
      print('📲 Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _notificationsHelper.markAllAsRead();
      await _loadNotificationsFromDB();
      print('📲 Marked all notifications as read');
    } catch (e) {
      print('📲 Error marking all as read: $e');
    }
  }

  /// Load notifications from Supabase DB
  Future<void> _loadNotificationsFromDB() async {
    try {
      final notifications = await _notificationsHelper.fetchNotifications();
      _notifications = notifications;

      // Notify UI of the loaded notifications
      for (final notification in notifications) {
        _notificationController.add(notification);
      }

      print('📲 Loaded ${notifications.length} notifications from DB');
    } catch (e) {
      print('📲 Error loading notifications from DB: $e');
    }
  }

  /// Setup Realtime subscription for new notifications
  void _setupRealtimeSubscription() {
    final userId = SupabaseClientManager().currentUser?.id;

    if (userId == null) {
      print('📲 Skipping Realtime subscription setup: User not logged in');
      return;
    }

    try {
      _realtimeChannel = _notificationsHelper.setupRealtimeSubscription(
        (notification) {
          // New notification from Realtime
          _loadNotificationsFromDB(); // Refresh from DB
        },
      );
      print('📲 Realtime subscription setup complete');
    } catch (e) {
      print('📲 Error setting up Realtime subscription: $e');
    }
  }

  /// Refresh notifications from DB (called by UI)
  Future<void> refreshFromDB() async {
    await _loadNotificationsFromDB();
  }

  /// Reinitialize notifications after user login
  /// This sets up the Realtime subscription and loads notifications
  Future<void> reinitializeAfterLogin() async {
    print('📲 Reinitializing FCM service after login');
    await _loadNotificationsFromDB();
    _setupRealtimeSubscription();
  }

  /// Cleanup on logout
  void cleanupOnLogout() {
    print('📲 Cleaning up FCM service on logout');
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _notifications = [];
  }

  /// Get unread count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Dispose
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _notificationController.close();
  }
}
