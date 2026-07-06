import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:login/app/app_root.dart';
import 'package:login/models/notification_type.dart';
import 'package:login/pages/bubble_messaging_page.dart';
import 'package:login/pages/profile/other_user_profile_page.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/supabase/service.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/supabase/helpers/notifications.dart';
import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notifications/bubble_message_notification.dart';
import 'package:login/models/notifications/follow_request_notification.dart';
import 'package:login/models/notifications/user_added_to_bubble_notification.dart';
import 'package:login/models/notifications/video_processed_notification.dart';
import 'package:login/widgets/profile/notifications_popover.dart';
import 'package:login/pages/social_review/social_post_review_page.dart';
import 'package:login/services/notification_routes.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/utils/route_open_guard.dart';

@visibleForTesting
bool shouldSyncFcmToken({
  required bool isApplePlatform,
  required String? apnsToken,
  required String? fcmToken,
}) {
  final normalizedFcmToken = fcmToken?.trim();
  if (normalizedFcmToken == null || normalizedFcmToken.isEmpty) {
    return false;
  }

  if (!isApplePlatform) {
    return true;
  }

  final normalizedApnsToken = apnsToken?.trim();
  return normalizedApnsToken != null && normalizedApnsToken.isNotEmpty;
}

@visibleForTesting
bool shouldClearFcmToken({required String? currentToken}) {
  final normalizedToken = currentToken?.trim();
  return normalizedToken != null && normalizedToken.isNotEmpty;
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  // Notification stream for UI
  final _notificationController =
      StreamController<BaseNotification>.broadcast();
  Stream<BaseNotification> get notificationStream =>
      _notificationController.stream;

  // Stream for location-saved events (emits locationId when a video is processed)
  final _locationSavedController = StreamController<int>.broadcast();
  Stream<int> get locationSavedStream => _locationSavedController.stream;

  List<BaseNotification> _notifications = [];
  List<BaseNotification> get notifications => List.unmodifiable(_notifications);
  final AnalyticsService _analyticsService = AnalyticsService();

  late final NotificationsHelper _notificationsHelper;
  RealtimeChannel? _realtimeChannel;
  bool _messageOpenHandlingRegistered = false;
  String? _lastKnownFcmToken;

  // Holds a tapped notification until MainScreen and the root navigator are
  // ready to actually push routes.
  RemoteMessage? _pendingOpenedMessage;

  /// Save FCM token to Supabase with retry logic
  Future<void> saveFCMToken(String fcmToken, {int retryCount = 0}) async {
    try {
      final userId = SupabaseClientManager().currentUser?.id;
      final normalizedToken = fcmToken.trim();

      if (userId == null) {
        print('📲 No user logged in, skipping FCM token save');
        return;
      }

      if (normalizedToken.isEmpty) {
        print('📲 No FCM token available to save');
        return;
      }

      await SupabaseClientManager().client.rpc(
        'update_fcm_token',
        params: {
          'p_user_id': userId,
          'p_fcm_token': normalizedToken,
        },
      );

      _lastKnownFcmToken = normalizedToken;
      print('📲 FCM token saved to Supabase');
    } catch (e) {
      print('📲 Error saving FCM token: $e');

      // Retry logic with exponential backoff
      if (retryCount < 3) {
        final delaySeconds = pow(2, retryCount); // 1s, 2s, 4s
        print(
            '📲 Retrying in ${delaySeconds}s... (attempt ${retryCount + 1}/3)');

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
      final token = await _getAvailableFcmToken(
        unavailableMessage: '📲 No FCM token available to save',
      );
      if (token == null) return;

      await saveFCMToken(token);
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

      final currentToken = _lastKnownFcmToken ??
          await _getAvailableFcmToken(
            unavailableMessage: '📲 No FCM token available to clear',
          );
      if (!shouldClearFcmToken(currentToken: currentToken)) {
        return;
      }

      await SupabaseClientManager().client.rpc(
        'update_fcm_token',
        params: {
          'p_user_id': userId,
          'p_fcm_token': '', // Clear token
        },
      );

      _lastKnownFcmToken = null;
      print('📲 FCM token cleared from Supabase');
    } catch (e) {
      print('📲 Error clearing FCM token: $e');
    }
  }

  /// Initialize FCM listeners
  Future<void> initialize() async {
    print('📲 Initializing FCM Service');

    await registerMessageOpenHandling();

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
    final token = await _getAvailableFcmToken(
      unavailableMessage: '📲 No FCM token available to save',
    );
    if (token != null) {
      await saveFCMToken(token);
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _lastKnownFcmToken = newToken;
      saveFCMToken(newToken);
    });

    // Handle foreground messages - save to DB instead of memory
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    print('📲 FCM Service initialization complete');
  }

  /// Register tap/open listeners as early as possible during bootstrap.
  ///
  /// This must happen before long-running startup work, otherwise iOS can
  /// deliver the "notification opened app" event before our listener exists.
  Future<void> registerMessageOpenHandling() async {
    if (_messageOpenHandlingRegistered) return;
    _messageOpenHandlingRegistered = true;

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_handleNotificationTapOrQueue(message));
    });

    _pendingOpenedMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (_pendingOpenedMessage != null) {
      print('📲 Stored initial notification tap for later consumption');
    }
  }

  /// Handle foreground notification
  void _handleForegroundMessage(RemoteMessage message) async {
    print('📲 Foreground notification received');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');

    final notification = BaseNotification.fromRemoteMessage(message);
    if (notification != null) {
      _analyticsService.track(
        eventName: 'notification_received',
        eventCategory: 'notification',
        properties: <String, dynamic>{
          'type': notification.type.name,
          'has_data': message.data.isNotEmpty,
          'source': 'foreground',
        },
      );
      // Emit location-saved event so the location list updates immediately
      if (notification.type == NotificationType.videoProcessed &&
          notification is VideoProcessedNotification) {
        final locationId = int.tryParse(notification.locationId);
        if (locationId != null) _locationSavedController.add(locationId);
      }

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

  /// Handle notification tap — navigate to the appropriate screen
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('📲 Notification tapped');
    final tappedNotification = BaseNotification.fromRemoteMessage(message);
    if (tappedNotification != null) {
      _analyticsService.track(
        eventName: 'notification_opened',
        eventCategory: 'notification',
        properties: <String, dynamic>{
          'type': tappedNotification.type.name,
          'source': 'tap',
        },
      );
    }

    final handledDeepLink = await _handleDeepLinkFromMessage(message);
    if (handledDeepLink) return;

    // Fallback: infer a deep link from type + IDs if no deepLink was provided
    // (or if the provided one was not handled).
    final dataWithoutDeepLink = Map<String, dynamic>.from(message.data);
    dataWithoutDeepLink.remove('deepLink');
    dataWithoutDeepLink.remove('deep_link');
    dataWithoutDeepLink.remove('deeplink');
    final inferredDeepLink = resolveNotificationDeepLink(dataWithoutDeepLink);
    if (inferredDeepLink != null) {
      final handledInferred =
          await _handleDeepLink(inferredDeepLink, message.data);
      if (handledInferred) return;
    }

    final notification = BaseNotification.fromRemoteMessage(message);
    if (notification == null) return;

    print('📲 Navigating for type: ${notification.type}');

    final context = navigatorKey.currentContext;

    // For most notification taps, open the in-app notifications layover so the
    // user lands in the same inbox experience as the bell in Profile.
    //
    // Keep message-style notifications deep-linking directly to the chat/bubble.
    if (notification.type != NotificationType.newMessage &&
        notification.type != NotificationType.userAddedToBubble) {
      await refreshFromDB();

      if (context != null) {
        try {
          Provider.of<NavigationProvider>(context, listen: false)
              .navigateToTab(2);
        } catch (_) {}
      }

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const NotificationsPopover(),
          fullscreenDialog: true,
        ),
      );
      return;
    }

    if (notification is BubbleMessageNotification) {
      await _openBubbleChat(
        bubbleId: notification.bubbleId,
        notificationId: notification.id,
        isRead: notification.isRead,
      );
      return;
    }

    if (notification is UserAddedToBubbleNotification) {
      await _openBubbleChat(
        bubbleId: notification.bubbleId,
        notificationId: notification.id,
        isRead: notification.isRead,
      );
    }
  }

  Future<void> _handleNotificationTapOrQueue(RemoteMessage message) async {
    if (!_isNavigatorReady()) {
      _queuePendingOpenedMessage(message, reason: 'navigator_not_ready');
      return;
    }

    try {
      await _handleNotificationTap(message);
    } catch (e) {
      print('📲 Error handling notification tap immediately: $e');
      _queuePendingOpenedMessage(message, reason: 'tap_handler_failed');
    }
  }

  String? _firstNonEmptyString(
    Map<String, dynamic> data,
    List<String> candidateKeys,
  ) {
    for (final key in candidateKeys) {
      final raw = data[key];
      final value = raw?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  List<String> _deepLinkSegments(String deepLink) {
    final uri = Uri.tryParse(deepLink);
    if (uri == null) return const [];

    if (uri.scheme.isNotEmpty) {
      final segments = <String>[];
      if (uri.host.isNotEmpty) segments.add(uri.host);
      segments.addAll(uri.pathSegments);
      return segments.where((s) => s.trim().isNotEmpty).toList();
    }

    final path = deepLink.split('?').first;
    final trimmed = path.startsWith('/') ? path.substring(1) : path;
    if (trimmed.trim().isEmpty) return const [];
    return trimmed
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<bool> _handleDeepLinkFromMessage(RemoteMessage message) async {
    final deepLink = _firstNonEmptyString(
      message.data,
      const ['deepLink', 'deep_link', 'deeplink'],
    );
    if (deepLink == null) return false;

    return _handleDeepLink(deepLink, message.data);
  }

  String _normalizeNotifType(Object? raw) {
    final normalized = (raw?.toString() ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return '';
    if (normalized == 'location_saved') return 'video_processed';
    if (normalized == 'proximity_locaiton') return 'proximity_location';
    return normalized;
  }

  Future<bool> _handleDeepLink(
      String deepLink, Map<String, dynamic> data) async {
    final segments = _deepLinkSegments(deepLink);
    if (segments.isEmpty) {
      _trackDeepLinkFailed(
        deepLink: deepLink,
        reason: 'empty_segments',
      );
      return false;
    }

    final context = navigatorKey.currentContext;
    final notificationId = data['id']?.toString();

    Future<void> markAsReadIfPossible() async {
      if (notificationId == null || notificationId.trim().isEmpty) return;
      try {
        await markAsRead(notificationId);
      } catch (_) {}
    }

    void navigateToTab(int tabIndex, String routeFallback) {
      if (context != null) {
        try {
          Provider.of<NavigationProvider>(context, listen: false)
              .navigateToTab(tabIndex);
          return;
        } catch (_) {}
      }
      navigatorKey.currentState?.pushNamed(routeFallback);
    }

    final root = segments.first;
    switch (root) {
      case 'home':
        navigateToTab(0, '/home');
        _trackDeepLinkRouted(deepLink: deepLink, route: 'home');
        return true;

      case 'bubbles':
        navigateToTab(1, '/bubbles');
        _trackDeepLinkRouted(deepLink: deepLink, route: 'bubbles');
        return true;

      case 'profile':
        navigateToTab(2, '/profile');
        _trackDeepLinkRouted(deepLink: deepLink, route: 'profile');
        return true;

      case 'notifications':
      case 'inbox':
        await refreshFromDB();
        navigateToTab(2, '/profile');
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => const NotificationsPopover(),
            fullscreenDialog: true,
          ),
        );
        _trackDeepLinkRouted(deepLink: deepLink, route: 'notifications');
        return true;

      case 'bubble':
        final bubbleId = (segments.length >= 2 ? segments[1] : null) ??
            _firstNonEmptyString(data, const ['bubbleId']);
        if (bubbleId == null) {
          _trackDeepLinkFailed(
            deepLink: deepLink,
            reason: 'missing_bubble_id',
            route: 'bubble',
          );
          return false;
        }
        await markAsReadIfPossible();
        await _openBubbleChat(
          bubbleId: bubbleId,
          notificationId: notificationId ?? '',
          isRead: true,
        );
        _trackDeepLinkRouted(deepLink: deepLink, route: 'bubble');
        return true;

      case 'user':
        final userId = (segments.length >= 2 ? segments[1] : null) ??
            _firstNonEmptyString(data, const ['userId']);
        if (userId == null) {
          _trackDeepLinkFailed(
            deepLink: deepLink,
            reason: 'missing_user_id',
            route: 'user',
          );
          return false;
        }
        await markAsReadIfPossible();
        await _openUserProfile(
          userId: userId,
          highlightPendingRequest:
              _normalizeNotifType(data['type']) == 'follow_request',
        );
        _trackDeepLinkRouted(deepLink: deepLink, route: 'user');
        return true;

      case 'location':
        final locationIdRaw = (segments.length >= 2 ? segments[1] : null) ??
            _firstNonEmptyString(data, const ['locationId']);
        final locationId = int.tryParse(locationIdRaw ?? '');
        if (locationId == null) {
          _trackDeepLinkFailed(
            deepLink: deepLink,
            reason: 'invalid_location_id',
            route: 'location',
          );
          return false;
        }
        await markAsReadIfPossible();
        await _openLocation(locationId: locationId);
        _trackDeepLinkRouted(deepLink: deepLink, route: 'location');
        return true;

      case 'social-review':
        final postId = (segments.length >= 2 ? segments[1] : null) ??
            _firstNonEmptyString(data, const ['socialPostId']);
        if (postId == null) {
          _trackDeepLinkFailed(
            deepLink: deepLink,
            reason: 'missing_social_post_id',
            route: 'social-review',
          );
          return false;
        }
        await markAsReadIfPossible();
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) =>
                SocialPostReviewPage(postId: postId, source: 'notification'),
          ),
        );
        _trackDeepLinkRouted(deepLink: deepLink, route: 'social-review');
        return true;

      default:
        _trackDeepLinkFailed(
          deepLink: deepLink,
          reason: 'unsupported_route',
          route: root,
        );
        return false;
    }
  }

  void _trackDeepLinkRouted({
    required String deepLink,
    required String route,
  }) {
    _analyticsService.track(
      eventName: 'deep_link_routed',
      eventCategory: 'notification',
      properties: <String, dynamic>{
        'deep_link': deepLink,
        'route': route,
      },
    );
  }

  void _trackDeepLinkFailed({
    required String deepLink,
    required String reason,
    String? route,
  }) {
    _analyticsService.track(
      eventName: 'deep_link_failed',
      eventCategory: 'notification',
      properties: <String, dynamic>{
        'deep_link': deepLink,
        'reason': reason,
        if (route != null) 'route': route,
      },
    );
    _analyticsService.recordError(
      key: 'deep_link_failed',
      properties: <String, dynamic>{
        'reason': reason,
        if (route != null) 'route': route,
      },
    );
  }

  Future<void> _openLocation({required int locationId}) async {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        try {
          Provider.of<NavigationProvider>(context, listen: false)
              .navigateToTab(0);
        } catch (_) {}
      }

      final locations =
          await SupabaseService().locations.getLocationsByIds([locationId]);
      if (locations.isEmpty) return;

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: ExpandedLocationCard(
              location: locations.first,
              onClose: () => navigatorKey.currentState?.pop(),
            ),
          ),
        ),
      );
    } catch (e) {
      print('📲 Error opening location: $e');
    }
  }

  Future<void> _openUserProfile({
    required String userId,
    required bool highlightPendingRequest,
  }) async {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        try {
          Provider.of<NavigationProvider>(context, listen: false)
              .navigateToTab(2);
        } catch (_) {}
      }

      final user = await SupabaseService().users.getUserProfileById(userId);
      if (user == null) return;

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      final userKey = user.supabaseId ?? user.email;
      unawaited(
        RouteOpenGuard.run<void>(
          'other-user-profile:$userKey',
          () => navigator.push<void>(
            MaterialPageRoute(
              builder: (_) => OtherUserProfilePage(
                user: user,
                highlightPendingRequest: highlightPendingRequest,
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      print('📲 Error opening user profile: $e');
    }
  }

  /// Deep-link into [BubbleMessagingPage] for the given bubble.
  Future<void> _openBubbleChat({
    required String bubbleId,
    required String notificationId,
    required bool isRead,
  }) async {
    try {
      final bubble = await SupabaseService().bubbles.getBubbleById(bubbleId);
      if (bubble == null) {
        print('📲 Bubble $bubbleId not found — falling back to bubbles tab');
        _navigateToTabFallback(1, '/bubbles');
        return;
      }

      if (!isRead) {
        await markAsRead(notificationId);
      }

      final context = navigatorKey.currentContext;
      if (context != null) {
        try {
          Provider.of<NavigationProvider>(context, listen: false)
              .navigateToTab(1);
        } catch (_) {}
      }

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => BubbleMessagingPage(bubble: bubble),
        ),
      );
    } catch (e) {
      print('📲 Error opening bubble chat: $e');
      _navigateToTabFallback(1, '/bubbles');
    }
  }

  void _navigateToTabFallback(int tabIndex, String routeName) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        Provider.of<NavigationProvider>(context, listen: false)
            .navigateToTab(tabIndex);
        return;
      } catch (_) {}
    }
    navigatorKey.currentState?.pushNamed(routeName);
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

  /// Mark any unread followRequest notifications from [requesterId] as read.
  /// Called after the current user accepts or rejects that user's request.
  Future<void> markFollowRequestAsReadFrom(String requesterId) async {
    final matching = _notifications
        .whereType<FollowRequestNotification>()
        .where((n) => !n.isRead && n.userId == requesterId)
        .toList();

    for (final n in matching) {
      try {
        await _notificationsHelper.markAsRead(n.id);
      } catch (e) {
        print('📲 Error marking follow request ${n.id} as read: $e');
      }
    }
    if (matching.isNotEmpty) {
      await _loadNotificationsFromDB();
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

  /// Call this once from MainScreen.initState to handle any queued tap.
  Future<void> consumePendingInitialMessage() async {
    if (!_isNavigatorReady()) {
      print('📲 Navigator still not ready; deferring pending notification tap');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(consumePendingInitialMessage());
      });
      return;
    }

    final message = _pendingOpenedMessage;
    if (message == null) return;
    _pendingOpenedMessage = null;
    await _handleNotificationTap(message);
  }

  bool _isNavigatorReady() {
    return navigatorKey.currentState != null &&
        navigatorKey.currentContext != null;
  }

  void _queuePendingOpenedMessage(
    RemoteMessage message, {
    required String reason,
  }) {
    _pendingOpenedMessage = message;
    print(
      '📲 Queued notification tap until navigator is ready '
      '($reason): ${message.data}',
    );
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
    _lastKnownFcmToken = null;
  }

  Future<String?> _getAvailableFcmToken({
    required String unavailableMessage,
  }) async {
    final isApplePlatform = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    String? apnsToken;

    if (isApplePlatform) {
      apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null || apnsToken.trim().isEmpty) {
        print('📲 APNS token not available yet, skipping FCM token sync');
        return null;
      }
    }

    final fcmToken = await FirebaseMessaging.instance.getToken();

    if (!shouldSyncFcmToken(
      isApplePlatform: isApplePlatform,
      apnsToken: apnsToken,
      fcmToken: fcmToken,
    )) {
      print(unavailableMessage);
      return null;
    }

    _lastKnownFcmToken = fcmToken!.trim();
    return _lastKnownFcmToken;
  }

  /// Get unread count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Dispose
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _notificationController.close();
    _locationSavedController.close();
  }
}
