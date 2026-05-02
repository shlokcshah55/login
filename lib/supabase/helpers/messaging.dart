import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/message.dart';
import '../../services/push_notification_service.dart';
import 'location.dart';
import '../constants.dart';
import '../supabase_client.dart';

class MessagingHelper {
  final SupabaseClient _client = SupabaseClientManager().client;
  final LocationHelper _locationHelper = LocationHelper();
  RealtimeChannel? _realtimeChannel;

  /// Initialize chat state for a bubble
  Future<void> initializeBubbleChat(String bubbleId) async {
    try {
      await _client.rpc('initialize_bubble_chat', params: {
        'p_bubble_id': bubbleId,
      });
    } catch (e) {
      if (kDebugMode) {
        print('MessagingHelper: Error initializing bubble chat: $e');
      }
      rethrow;
    }
  }

  /// Send a message to a bubble
  Future<String?> sendMessage({
    required String bubbleId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
    String? repliedToMessageId,
    int? locationId,
  }) async {
    try {
      final result = await _client.rpc('send_message', params: {
        'p_bubble_id': bubbleId,
        'p_content': content,
        'p_message_type': messageType,
        'p_metadata': metadata,
        'p_replied_to': repliedToMessageId,
        'p_location_id': locationId,
      });

      print('Suceeded over here');

      if (kDebugMode) {
        print('MessagingHelper: Message sent, id: $result');
      }

      // Send push notifications to all bubble members except sender
      final user = SupabaseClientManager().currentUser;
      if (user != null) {
        final notificationPreview = content.trim().isNotEmpty
            ? content
            : (locationId != null ? 'Shared a location' : content);

        // Fire and forget - don't wait for notifications to complete
        PushNotificationService()
            .sendBubbleMessageNotification(
          bubbleId: bubbleId,
          senderId: user.id,
          messageContent: notificationPreview,
        )
            .catchError((error) {
          if (kDebugMode) {
            print('MessagingHelper: Error sending push notifications: $error');
          }
          // Don't throw - notifications are non-critical
        });
      }

      return result as String?;
    } catch (e) {
      if (kDebugMode) {
        print('MessagingHelper: Error sending message: $e');
      }
      rethrow;
    }
  }

  /// Get messages for a bubble with pagination
  Future<List<MessageModel>> getBubbleMessages({
    required String bubbleId,
    int limit = 50,
    DateTime? beforeTimestamp,
  }) async {
    try {
      final result = await _client.rpc('get_bubble_messages', params: {
        'p_bubble_id': bubbleId,
        'p_limit': limit,
        'p_before_timestamp': beforeTimestamp?.toUtc().toIso8601String(),
      });

      if (result == null) {
        return [];
      }

      final messages = (result as List)
          .map((json) => MessageModel.fromJson(json, bubbleId: bubbleId))
          .toList();

      final locationIds = messages
          .map((message) => message.locationId)
          .whereType<int>()
          .toSet()
          .toList();

      if (locationIds.isNotEmpty) {
        final locations = await _locationHelper.getLocationsByIds(locationIds);
        final locationsById = {
          for (final location in locations) location.locationId: location,
        };

        for (var i = 0; i < messages.length; i++) {
          final locationId = messages[i].locationId;
          if (locationId == null) continue;
          messages[i] = messages[i].copyWith(
            location: locationsById[locationId],
          );
        }
      }

      if (kDebugMode) {
        print('MessagingHelper: Loaded ${messages.length} messages');
      }

      return messages;
    } catch (e) {
      if (kDebugMode) {
        print('MessagingHelper: Error getting messages: $e');
      }
      rethrow;
    }
  }

  /// Mark a bubble's messages as read
  Future<void> markBubbleRead(String bubbleId) async {
    try {
      await _client.rpc('mark_bubble_read', params: {
        'p_bubble_id': bubbleId,
      });

      if (kDebugMode) {
        print('MessagingHelper: Marked bubble $bubbleId as read');
      }
    } catch (e) {
      if (kDebugMode) {
        print('MessagingHelper: Error marking bubble read: $e');
      }
      rethrow;
    }
  }

  /// Like/unlike a message
  Future<bool> setMessageLiked({
    required String messageId,
    required bool liked,
  }) async {
    try {
      final result = await _client.rpc('set_message_liked', params: {
        'p_message_id': messageId,
        'p_liked': liked,
      });

      return result as bool? ?? liked;
    } catch (e) {
      if (kDebugMode) {
        print('MessagingHelper: Error setting message liked: $e');
      }
      rethrow;
    }
  }

  /// Get unread message count for a bubble
  Future<int> getUnreadCount(String bubbleId) async {
    try {
      final user = SupabaseClientManager().currentUser;
      if (user == null) {
        return 0;
      }

      // Query user_bubble_chats view for unread_count
      final result = await _client
          .from('user_bubble_chats')
          .select('unread_count')
          .eq('bubble_id', bubbleId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (result == null) {
        // No chat state means user hasn't initialized chat yet
        return 0;
      }

      return result['unread_count'] as int? ?? 0;
    } catch (e) {
      if (kDebugMode) {
        print('MessagingHelper: Error getting unread count: $e');
      }
      return 0;
    }
  }

  /// Get total message count for a bubble
  Future<int> getMessageCount(String bubbleId) async {
    try {
      final result = await _client
          .from(SupabaseConstants.tableMessages)
          .select('id')
          .eq(SupabaseConstants.columnBubbleId, bubbleId)
          .eq(SupabaseConstants.columnIsDeleted, false);

      return (result as List).length;
    } catch (e) {
      if (kDebugMode) {
        print('MessagingHelper: Error getting message count: $e');
      }
      return 0;
    }
  }

  /// Subscribe to realtime message updates for a bubble
  void subscribeToMessages(
    String bubbleId,
    void Function(PostgresChangePayload) onEvent,
  ) {
    // Clean up any existing subscription first
    unsubscribeFromMessages();

    if (kDebugMode) {
      print('MessagingHelper: Subscribing to messages for bubble: $bubbleId');
    }

    _realtimeChannel = _client
        .channel('messages:$bubbleId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.tableMessages,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: SupabaseConstants.columnBubbleId,
            value: bubbleId,
          ),
          callback: onEvent,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.tableMessages,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: SupabaseConstants.columnBubbleId,
            value: bubbleId,
          ),
          callback: onEvent,
        )
        .subscribe();
  }

  /// Unsubscribe from realtime message updates
  void unsubscribeFromMessages() {
    if (_realtimeChannel != null) {
      if (kDebugMode) {
        print('MessagingHelper: Unsubscribing from messages');
      }
      _client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }
}
