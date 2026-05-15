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

      await _client.from(SupabaseConstants.tableNotifications).insert({
        SupabaseConstants.columnNotificationId: notification.id,
        SupabaseConstants.columnType: typeString,
        SupabaseConstants.columnMetadata: metadata,
        SupabaseConstants.columnIsRead: notification.isRead,
        SupabaseConstants.columnUserId: userId,
        SupabaseConstants.columnCreatedAt: notification.timestamp.toIso8601String(),
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
          .from(SupabaseConstants.tableNotifications)
          .update({SupabaseConstants.columnIsRead: true})
          .eq(SupabaseConstants.columnNotificationId, notificationId);

      print('📲 Marked notification $notificationId as read in DB');
    } catch (e) {
      print('📲 Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark unread new-message notifications as read once the bubble itself has
  /// been opened and its messages are considered seen.
  Future<int> markBubbleMessageNotificationsAsRead(String bubbleId) async {
    try {
      final userId = SupabaseClientManager().currentUser?.id;

      if (userId == null) {
        print(
          '📲 No user logged in, cannot clear bubble message notifications',
        );
        return 0;
      }

      final response = await _client
          .from(SupabaseConstants.tableNotifications)
          .select('''
            ${SupabaseConstants.columnNotificationId},
            ${SupabaseConstants.columnMetadata}
          ''')
          .eq(SupabaseConstants.columnUserId, userId)
          .eq(SupabaseConstants.columnType, 'new_message')
          .eq(SupabaseConstants.columnIsRead, false);

      final matchingIds = (response as List)
          .whereType<Map<String, dynamic>>()
          .where((row) {
            final metadata = row[SupabaseConstants.columnMetadata];
            if (metadata is! Map<String, dynamic>) return false;
            return metadata['bubbleId']?.toString() == bubbleId;
          })
          .map((row) => row[SupabaseConstants.columnNotificationId]?.toString())
          .whereType<String>()
          .toList();

      if (matchingIds.isEmpty) {
        return 0;
      }

      await _client
          .from(SupabaseConstants.tableNotifications)
          .update({SupabaseConstants.columnIsRead: true})
          .inFilter(SupabaseConstants.columnNotificationId, matchingIds);

      print(
        '📲 Marked ${matchingIds.length} bubble message notifications as read',
      );
      return matchingIds.length;
    } catch (e) {
      print('📲 Error clearing bubble message notifications: $e');
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
          .from(SupabaseConstants.tableNotifications)
          .update({SupabaseConstants.columnIsRead: true})
          .eq(SupabaseConstants.columnUserId, userId);

      print('📲 Marked all notifications as read in DB');
    } catch (e) {
      print('📲 Error marking all notifications as read: $e');
      rethrow;
    }
  }

  /// Setup Realtime subscription for notification inserts, updates, and deletes.
  /// Calls [onChange] whenever any notification row for the current user changes.
  /// Note: User must be logged in before calling this method
  RealtimeChannel setupRealtimeSubscription(
    Function(BaseNotification?) onChange,
  ) {
    final userId = SupabaseClientManager().currentUser!.id;

    print('📲 Setting up Realtime subscription for user $userId');

    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: userId,
    );

    void handle(PostgresChangePayload payload) {
      print('📲 Realtime notification ${payload.eventType}: '
          'new=${payload.newRecord} old=${payload.oldRecord}');
      try {
        final record = payload.newRecord.isNotEmpty
            ? payload.newRecord
            : payload.oldRecord;
        final notification = record.isNotEmpty
            ? BaseNotification.fromSupabase(record)
            : null;
        onChange(notification);
      } catch (e) {
        print('📲 Error parsing Realtime notification: $e');
        onChange(null);
      }
    }

    final channel = _client
        .channel('notifications:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: filter,
          callback: handle,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: filter,
          callback: handle,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          filter: filter,
          callback: handle,
        )
        .subscribe();

    return channel;
  }
}
