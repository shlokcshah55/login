import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';
import '../supabase/helpers/messaging.dart';
import '../supabase/supabase_client.dart';

class MessagingProvider with ChangeNotifier {
  final MessagingHelper _messagingHelper;
  final String bubbleId;

  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSending = false;
  bool _hasMore = true;
  String? _error;
  bool _isSubscribed = false;

  MessagingProvider({
    required this.bubbleId,
    required MessagingHelper messagingHelper,
  }) : _messagingHelper = messagingHelper;

  // Getters
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isSending => _isSending;
  bool get hasMore => _hasMore;
  String? get error => _error;

  String? get currentUserId => SupabaseClientManager().currentUser?.id;

  /// Initialize the provider and load messages
  Future<void> initialize() async {
    await _initializeBubbleChat();
    await loadMessages();
    _subscribeToRealtime();
    await _markAsRead();
  }

  /// Initialize chat state for this bubble
  Future<void> _initializeBubbleChat() async {
    try {
      await _messagingHelper.initializeBubbleChat(bubbleId);
    } catch (e) {
      if (kDebugMode) {
        print('MessagingProvider: Error initializing chat: $e');
      }
    }
  }

  /// Load initial messages
  Future<void> loadMessages() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final messages = await _messagingHelper.getBubbleMessages(
        bubbleId: bubbleId,
        limit: 50,
      );

      _messages = messages;
      _hasMore = messages.length >= 50;

      if (kDebugMode) {
        print('MessagingProvider: Loaded ${messages.length} messages');
      }
    } catch (e) {
      _error = 'Failed to load messages: $e';
      if (kDebugMode) {
        print('MessagingProvider: $_error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more messages (pagination)
  Future<void> loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      // Get the oldest message's timestamp for pagination
      final oldestMessage = _messages.last;

      final moreMessages = await _messagingHelper.getBubbleMessages(
        bubbleId: bubbleId,
        limit: 50,
        beforeTimestamp: oldestMessage.createdAt,
      );

      _messages.addAll(moreMessages);
      _hasMore = moreMessages.length >= 50;

      if (kDebugMode) {
        print('MessagingProvider: Loaded ${moreMessages.length} more messages');
      }
    } catch (e) {
      if (kDebugMode) {
        print('MessagingProvider: Error loading more messages: $e');
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Send a message
  Future<bool> sendMessage(
    String content, {
    String? replyToId,
    int? locationId,
  }) async {
    if (_isSending || content.trim().isEmpty) return false;

    _isSending = true;
    notifyListeners();

    try {
      await _messagingHelper.sendMessage(
        bubbleId: bubbleId,
        content: content.trim(),
        repliedToMessageId: replyToId,
        locationId: locationId,
      );

      if (kDebugMode) {
        print('MessagingProvider: Message sent');
      }

      return true;
    } catch (e) {
      _error = 'Failed to send message: $e';
      if (kDebugMode) {
        print('MessagingProvider: $_error');
      }
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Subscribe to real-time message updates
  void _subscribeToRealtime() {
    if (_isSubscribed) return;

    _messagingHelper.subscribeToMessages(
      bubbleId,
      (payload) {
        _handleRealtimeEvent(payload);
      },
    );

    _isSubscribed = true;
  }

  /// Handle real-time message events
  void _handleRealtimeEvent(PostgresChangePayload payload) async {
    if (payload.eventType == PostgresChangeEvent.insert) {
      // Reload the latest message from the server to get full sender info
      // This is a simple approach - could be optimized later
      final messages = await _messagingHelper.getBubbleMessages(
        bubbleId: bubbleId,
        limit: 1,
      );

      if (messages.isNotEmpty) {
        final newMessage = messages.first;

        // Check if we already have this message
        final exists = _messages.any((m) => m.id == newMessage.id);
        if (!exists) {
          _messages.insert(0, newMessage);
          notifyListeners();

          if (kDebugMode) {
            print('MessagingProvider: New message received via realtime');
          }
        }
      }

      // Mark as read if we received a new message
      await _markAsRead();
    }
  }

  /// Mark the bubble as read
  Future<void> _markAsRead() async {
    try {
      await _messagingHelper.markBubbleRead(bubbleId);
    } catch (e) {
      if (kDebugMode) {
        print('MessagingProvider: Error marking as read: $e');
      }
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _messagingHelper.unsubscribeFromMessages();
    super.dispose();
  }
}
