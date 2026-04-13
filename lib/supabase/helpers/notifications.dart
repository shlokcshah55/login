import 'package:login/supabase/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/models/notifications/base_notification.dart';

/// Helper class for notification database operations
class NotificationsHelper {
  final SupabaseClient _client = SupabaseClientManager().client;

  /// Fetch notifications from database for the current user
  /// Returns up to [limit] notifications ordered by creation time (newest first)
  Future<List<BaseNotification>> fetchNotifications({int limit = 50}) async {
    try {
      final userId = SupabaseClientManager().currentUser?.id;

      if (userId == null) {
        print('📲 No user logged in, cannot fetch notifications');
        return [];
      }

      final response = await _client
          .from(SupabaseConstants.tableNotifications)
          .select('''
            ${SupabaseConstants.columnNotificationId},
            ${SupabaseConstants.columnType},
            title,
            message,
            ${SupabaseConstants.columnMetadata},
            ${SupabaseConstants.columnIsRead},
            ${SupabaseConstants.columnUserId},
            ${SupabaseConstants.columnCreatedAt}
          ''')
          .eq('${SupabaseConstants.columnUserId}', userId)
          .order('${SupabaseConstants.columnCreatedAt}', ascending: false)
          .limit(limit);

      final notifications = <BaseNotification>[];
      for (final row in response as List) {
        final notification = BaseNotification.fromSupabase(row);
        if (notification != null) {
          notifications.add(notification);
        }
      }

      print('📲 Fetched ${notifications.length} notifications from DB');
      return notifications;
    } catch (e) {
      print('📲 Error fetching notifications: $e');
      return [];
    }
  }

  /// Save a notification to the database
  /// Called when a new FCM notification arrives
  Future<void> saveNotification(BaseNotification notification) async {
    try {
      final userId = SupabaseClientManager().currentUser?.id;

      if (userId == null) {
        print('📲 No user logged in, cannot save notification');
        return;
      }

      // Convert notification type enum to string
      final typeString = notification.type.toString().split('.').last;

      // Get metadata from the notification's toFCMData method
      final fcmData = notification.toFCMData();

      // Extract metadata (remove base fields that are columns)
      final metadata = Map<String, dynamic>.from(fcmData);
      metadata.remove('id');
      metadata.remove('timestamp');
      metadata.remove('type');

      await _client.from('notifications').insert({
        'notification_id': notification.id,
        'type': typeString,
        'metadata': metadata,
        'is_read': notification.isRead,
        'user_id': userId,
        'created_at': notification.timestamp.toIso8601String(),
      });

      print('📲 Saved notification ${notification.id} to DB');
    } catch (e) {
      print('📲 Error saving notification: $e');
      rethrow;
    }
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true}).eq('notification_id', notificationId);

      print('📲 Marked notification $notificationId as read in DB');
    } catch (e) {
      print('📲 Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read for the current user
  Future<void> markAllAsRead() async {
    try {
      final userId = SupabaseClientManager().currentUser?.id;

      if (userId == null) {
        print('📲 No user logged in, cannot mark all as read');
        return;
      }

      await _client
          .from('notifications')
          .update({'is_read': true}).eq('user_id', userId);

      print('📲 Marked all notifications as read in DB');
    } catch (e) {
      print('📲 Error marking all notifications as read: $e');
      rethrow;
    }
  }

  /// Setup Realtime subscription for new notifications
  /// Calls [onNewNotification] when a new notification is inserted for the current user
  /// Note: User must be logged in before calling this method
  RealtimeChannel setupRealtimeSubscription(
    Function(BaseNotification) onNewNotification,
  ) {
    final userId = SupabaseClientManager().currentUser!.id;

    print('📲 Setting up Realtime subscription for user $userId');

    final channel = _client
        .channel('notifications:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            print('📲 Realtime notification received: ${payload.newRecord}');
            try {
              final notification =
                  BaseNotification.fromSupabase(payload.newRecord);
              if (notification != null) {
                onNewNotification(notification);
              }
            } catch (e) {
              print('📲 Error parsing Realtime notification: $e');
            }
          },
        )
        .subscribe();

    return channel;
  }
}
