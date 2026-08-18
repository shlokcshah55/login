import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bubble.dart';
import '../supabase/helpers/bubbles.dart';
import '../supabase/supabase_client.dart';
import '../supabase/constants.dart';

class BubblesProvider with ChangeNotifier {
  final BubbleHelper _bubbleHelper;
  final String userId;

  List<Bubble> _bubbles = [];
  bool _isLoading = false;
  String? _error;
  bool _isSubscribed = false;
  bool _isMounted = true; // Track if provider is still active

  RealtimeChannel? _bubblesChannel;
  RealtimeChannel? _membersChannel;
  RealtimeChannel? _locationsChannel;
  RealtimeChannel? _messagesChannel;

  BubblesProvider({
    required this.userId,
    required BubbleHelper bubbleHelper,
  }) : _bubbleHelper = bubbleHelper;

  // Getters
  List<Bubble> get bubbles => _bubbles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalUnreadCount =>
      _bubbles.fold(0, (sum, bubble) => sum + bubble.unreadCount);

  // Override notifyListeners to prevent calling after dispose
  @override
  void notifyListeners() {
    if (_isMounted) {
      super.notifyListeners();
    }
  }

  /// Initialize the provider and load bubbles
  Future<void> initialize() async {
    await loadBubbles();
    _subscribeToRealtime();
  }

  /// Load bubbles from the database
  Future<void> loadBubbles() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bubbles = await _bubbleHelper.getUserBubbles(userId);
      _bubbles = bubbles.map(_mergeBubbleWithExistingUnread).toList()
        ..sort(_compareByLastActivity);

      if (kDebugMode) {
        print('BubblesProvider: Loaded ${bubbles.length} bubbles');
      }
    } catch (e) {
      _error = 'Failed to load bubbles: $e';
      if (kDebugMode) {
        print('BubblesProvider: $_error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to realtime updates
  void _subscribeToRealtime() {
    if (_isSubscribed) return;

    final client = SupabaseClientManager().client;

    // Subscribe to bubble_members changes (when user is added/removed from bubbles)
    _membersChannel = client
        .channel('bubble_members:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.tableBubbleMembers,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: SupabaseConstants.columnUserId,
            value: userId,
          ),
          callback: _handleMemberInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: SupabaseConstants.tableBubbleMembers,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: SupabaseConstants.columnUserId,
            value: userId,
          ),
          callback: _handleMemberDelete,
        )
        .subscribe();

    // Subscribe to bubbles table for name/metadata changes
    _bubblesChannel = client
        .channel('bubbles:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.tableBubbles,
          callback: _handleBubbleUpdate,
        )
        .subscribe();

    // Subscribe to bubble_locations changes (for any bubble we're in)
    _locationsChannel = client
        .channel('bubble_locations:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConstants.tableBubbleLocations,
          callback: _handleLocationChange,
        )
        .subscribe();

    // Subscribe to messages table for last message updates
    _messagesChannel = client
        .channel('messages:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.tableMessages,
          callback: _handleNewMessage,
        )
        .subscribe();

    _isSubscribed = true;

    if (kDebugMode) {
      print('BubblesProvider: Subscribed to realtime updates');
    }
  }

  /// Handle when user is added to a bubble
  void _handleMemberInsert(PostgresChangePayload payload) async {
    try {
      final bubbleId =
          payload.newRecord[SupabaseConstants.columnBubbleId] as String?;
      if (bubbleId == null) return;

      if (kDebugMode) {
        print('BubblesProvider: User added to bubble $bubbleId');
      }

      // Fetch the new bubble and add it to the list
      final bubble = await _bubbleHelper.getBubbleById(bubbleId);
      if (bubble != null) {
        _bubbles.insert(0, _mergeBubbleWithExistingUnread(bubble));
        _sortBubblesByActivity();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('BubblesProvider: Error handling member insert: $e');
      }
    }
  }

  /// Handle when user is removed from a bubble
  void _handleMemberDelete(PostgresChangePayload payload) {
    try {
      final bubbleId =
          payload.oldRecord[SupabaseConstants.columnBubbleId] as String?;
      if (bubbleId == null) return;

      if (kDebugMode) {
        print('BubblesProvider: User removed from bubble $bubbleId');
      }

      // Remove the bubble from the list
      _bubbles.removeWhere((b) => b.id == bubbleId);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('BubblesProvider: Error handling member delete: $e');
      }
    }
  }

  /// Handle bubble metadata updates (name, etc.)
  void _handleBubbleUpdate(PostgresChangePayload payload) async {
    try {
      final bubbleId =
          payload.newRecord[SupabaseConstants.columnBubbleId] as String?;
      if (bubbleId == null) return;

      if (kDebugMode) {
        print('BubblesProvider: Bubble $bubbleId updated');
      }

      // Find and update the bubble
      final index = _bubbles.indexWhere((b) => b.id == bubbleId);
      if (index != -1) {
        // Reload the bubble to get fresh data
        final updatedBubble = await _bubbleHelper.getBubbleById(bubbleId);
        if (updatedBubble != null) {
          _bubbles[index] = _mergeBubbleWithExistingUnread(updatedBubble);
          _sortBubblesByActivity();
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('BubblesProvider: Error handling bubble update: $e');
      }
    }
  }

  /// Handle location changes (add/remove) in bubbles
  void _handleLocationChange(PostgresChangePayload payload) async {
    try {
      final bubbleId =
          payload.newRecord[SupabaseConstants.columnBubbleId] as String? ??
              payload.oldRecord[SupabaseConstants.columnBubbleId] as String?;

      if (bubbleId == null) return;

      if (kDebugMode) {
        print('BubblesProvider: Location changed in bubble $bubbleId');
      }

      // Find and update the bubble
      final index = _bubbles.indexWhere((b) => b.id == bubbleId);
      if (index != -1) {
        // Reload the bubble to get fresh locations
        final updatedBubble = await _bubbleHelper.getBubbleById(bubbleId);
        if (updatedBubble != null) {
          _bubbles[index] = _mergeBubbleWithExistingUnread(updatedBubble);
          _sortBubblesByActivity();
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('BubblesProvider: Error handling location change: $e');
      }
    }
  }

  /// Handle new messages to update last message
  void _handleNewMessage(PostgresChangePayload payload) async {
    try {
      final bubbleId =
          payload.newRecord[SupabaseConstants.columnBubbleId] as String?;
      final content =
          (payload.newRecord[SupabaseConstants.columnContent] as String?)
              ?.trim();
      final createdAt =
          payload.newRecord[SupabaseConstants.columnCreatedAt] as String?;
      final hasLocation = payload.newRecord['location_id'] != null;

      if (bubbleId == null || createdAt == null) return;

      if (kDebugMode) {
        print('BubblesProvider: New message in bubble $bubbleId');
      }

      // Find and update the bubble
      final index = _bubbles.indexWhere((b) => b.id == bubbleId);
      if (index != -1) {
        // Update last message and time
        final updatedBubble = _bubbles[index].copyWith(
          lastMessage: (content != null && content.isNotEmpty)
              ? content
              : (hasLocation ? 'Shared a place' : _bubbles[index].lastMessage),
          lastMessageTime: _getTimeAgo(DateTime.parse(createdAt)),
          lastActivityAt: DateTime.parse(createdAt),
          unreadCount: _bubbles[index].unreadCount + 1,
        );

        _bubbles[index] = updatedBubble;
        _sortBubblesByActivity();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('BubblesProvider: Error handling new message: $e');
      }
    }
  }

  /// Helper function to format time ago
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Manually refresh a specific bubble
  Future<void> refreshBubble(String bubbleId) async {
    try {
      final updatedBubble = await _bubbleHelper.getBubbleById(bubbleId);
      if (updatedBubble != null) {
        final index = _bubbles.indexWhere((b) => b.id == bubbleId);
        if (index != -1) {
          _bubbles[index] = _mergeBubbleWithExistingUnread(updatedBubble);
          _sortBubblesByActivity();
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('BubblesProvider: Error refreshing bubble: $e');
      }
    }
  }

  void markBubbleReadLocally(String bubbleId) {
    final index = _bubbles.indexWhere((bubble) => bubble.id == bubbleId);
    if (index == -1) return;

    final bubble = _bubbles[index];
    if (bubble.unreadCount == 0) return;

    _bubbles[index] = bubble.copyWith(unreadCount: 0);
    notifyListeners();
  }

  /// Removes a bubble from the user's list.
  ///
  /// If the user is the creator, this will attempt to delete the bubble.
  /// Otherwise (or if deletion is not permitted), it will fall back to leaving.
  Future<bool> deleteOrLeaveBubble(String bubbleId) async {
    try {
      final deleted = await _bubbleHelper.deleteBubble(bubbleId: bubbleId);
      if (deleted) {
        _bubbles.removeWhere((b) => b.id == bubbleId);
        notifyListeners();
        return true;
      }

      final left = await _bubbleHelper.leaveBubble(
        bubbleId: bubbleId,
        userId: userId,
      );
      if (left) {
        _bubbles.removeWhere((b) => b.id == bubbleId);
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('BubblesProvider: Error deleting/leaving bubble: $e');
      }
      return false;
    }
  }

  /// Renames a bubble in-place (creator-only via RLS).
  Future<bool> renameBubble(String bubbleId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return false;

    try {
      final ok =
          await _bubbleHelper.renameBubble(bubbleId: bubbleId, name: trimmed);
      if (!ok) return false;

      final index = _bubbles.indexWhere((b) => b.id == bubbleId);
      if (index != -1) {
        _bubbles[index] = _bubbles[index].copyWith(name: trimmed);
        notifyListeners();
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('BubblesProvider: Error renaming bubble: $e');
      }
      return false;
    }
  }

  @override
  void dispose() {
    // Mark as not mounted to prevent notifyListeners after dispose
    _isMounted = false;

    // Unsubscribe from all channels
    final client = SupabaseClientManager().client;

    if (_membersChannel != null) {
      client.removeChannel(_membersChannel!);
      _membersChannel = null;
    }

    if (_bubblesChannel != null) {
      client.removeChannel(_bubblesChannel!);
      _bubblesChannel = null;
    }

    if (_locationsChannel != null) {
      client.removeChannel(_locationsChannel!);
      _locationsChannel = null;
    }

    if (_messagesChannel != null) {
      client.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }

    if (kDebugMode) {
      print('BubblesProvider: Disposed and unsubscribed from all channels');
    }

    super.dispose();
  }

  void _sortBubblesByActivity() {
    _bubbles.sort(_compareByLastActivity);
  }

  Bubble _mergeBubbleWithExistingUnread(Bubble incoming) {
    final existingIndex =
        _bubbles.indexWhere((bubble) => bubble.id == incoming.id);
    if (existingIndex == -1) {
      return incoming;
    }

    final existing = _bubbles[existingIndex];
    if (incoming.unreadCount > 0 || existing.unreadCount == 0) {
      return incoming;
    }

    return incoming.copyWith(unreadCount: existing.unreadCount);
  }

  int _compareByLastActivity(Bubble a, Bubble b) {
    final aTime = a.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  }
}
