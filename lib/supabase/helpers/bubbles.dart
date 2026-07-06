import 'package:flutter/foundation.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/bubble_summary.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/actions.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/supabase/helpers/location.dart';
import 'package:login/supabase/helpers/messaging.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/services/push_notification_service.dart';

/// Repository for bubble-related operations
class BubbleHelper {
  BubbleHelper({
    LocationHelper? locationService,
    MessagingHelper? messagingHelper,
  })  : _locationService = locationService ?? LocationHelper(),
        _messagingHelper = messagingHelper ?? MessagingHelper();

  final _client = SupabaseClientManager().client;
  final LocationHelper _locationService;
  final MessagingHelper _messagingHelper;

  /// Get lightweight bubble records for simple selection UI.
  ///
  /// This intentionally avoids loading members, locations, latest messages,
  /// unread counts, and compatibility scores. Use [getUserBubbles] when the
  /// full bubbles feed needs those hydrated fields.
  Future<List<BubbleSummary>> getUserBubbleSummaries(String userId) async {
    try {
      final response =
          await _client.from(SupabaseConstants.tableBubbleMembers).select('''
            ${SupabaseConstants.columnBubbleId},
            ${SupabaseConstants.tableBubbles}!inner(
              ${SupabaseConstants.columnBubbleId},
              ${SupabaseConstants.columnName},
              ${SupabaseConstants.columnCreatedBy},
              ${SupabaseConstants.columnCreatedAt},
              ${SupabaseConstants.columnIsPrivate}
            )
          ''').eq(SupabaseConstants.columnUserId, userId);

      final summaries = (response as List)
          .map((item) {
            final bubble =
                item[SupabaseConstants.tableBubbles] as Map<String, dynamic>?;
            if (bubble == null) return null;

            final createdAtRaw = bubble[SupabaseConstants.columnCreatedAt];
            final createdAt =
                createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null;

            return BubbleSummary(
              id: (bubble[SupabaseConstants.columnBubbleId] ??
                      item[SupabaseConstants.columnBubbleId])
                  .toString(),
              name: (bubble[SupabaseConstants.columnName] ?? 'Unnamed Bubble')
                  .toString(),
              createdBy:
                  (bubble[SupabaseConstants.columnCreatedBy] ?? '').toString(),
              createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
              isPrivate: bubble[SupabaseConstants.columnIsPrivate] == true,
            );
          })
          .whereType<BubbleSummary>()
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final hydratedSummaries = await Future.wait(
        summaries.map((summary) async {
          final members = await _getBubbleMembers(summary.id);
          return summary.copyWith(
            memberCount: members.length,
            memberAvatars: members
                .map(
                  (member) =>
                      (member[SupabaseConstants.columnProfileImageUrl] ?? '')
                          .toString(),
                )
                .toList(),
            memberNames: members
                .map((member) =>
                    (member[SupabaseConstants.name] ?? '').toString())
                .where((name) => name.isNotEmpty)
                .toList(),
          );
        }),
      );

      return hydratedSummaries;
    } catch (e) {
      if (kDebugMode) {
        print('Error in BubbleRepository.getUserBubbleSummaries: $e');
      }
      rethrow;
    }
  }

  /// Get all bubbles for the current user
  Future<List<Bubble>> getUserBubbles(String userId) async {
    try {
      // Get bubbles where user is a member
      final response =
          await _client.from(SupabaseConstants.tableBubbleMembers).select('''
            ${SupabaseConstants.columnBubbleId},
            ${SupabaseConstants.tableBubbles}!inner(
              ${SupabaseConstants.columnBubbleId},
              ${SupabaseConstants.columnName},
              ${SupabaseConstants.columnCreatedBy},
              ${SupabaseConstants.columnCreatedAt},
              ${SupabaseConstants.columnIsPrivate}
            )
          ''').eq(SupabaseConstants.columnUserId, userId);

      if ((response as List).isEmpty) {
        return [];
      }

      List<Bubble> bubbles = [];

      for (var item in response as List) {
        final bubble = item[SupabaseConstants.tableBubbles];
        final bubbleId = bubble[SupabaseConstants.columnBubbleId];
        final bubbleCreatedAt =
            DateTime.parse(bubble[SupabaseConstants.columnCreatedAt]);

        // Fetch bubble metadata in parallel so list ordering can follow
        // actual conversation activity instead of creation order.
        final results = await Future.wait([
          _getBubbleMembers(bubbleId),
          getBubbleLocations(bubbleId),
          _getCompatibilityScore(bubbleId),
          _getLatestMessagePreview(bubbleId),
          _messagingHelper.getUnreadCount(bubbleId),
        ]);

        final members = results[0] as List<Map<String, dynamic>>;
        final locations = results[1] as List<LocationModel>;
        final score = results[2] as int?;
        final latestMessage = results[3] as _BubbleMessagePreview?;
        final unreadCount = results[4] as int;
        final lastActivityAt = latestMessage?.createdAt ?? bubbleCreatedAt;

        bubbles.add(Bubble(
          id: bubbleId,
          name: bubble[SupabaseConstants.columnName] ?? 'Unnamed Bubble',
          createdBy: bubble[SupabaseConstants.columnCreatedBy] ?? '',
          lastMessage: latestMessage?.content ?? 'Tap to view locations',
          lastMessageTime: _getTimeAgo(lastActivityAt),
          lastActivityAt: lastActivityAt,
          memberCount: members.length,
          memberAvatars: members
              .map((m) =>
                  (m[SupabaseConstants.columnProfileImageUrl] ?? '') as String)
              .toList(),
          groupAvatar: members.isNotEmpty
              ? (members.first[SupabaseConstants.columnProfileImageUrl] ?? '')
              : '',
          isOnline: true,
          unreadCount: unreadCount,
          groupLocations: locations,
          description: 'Created ${_getTimeAgo(bubbleCreatedAt)}',
          memberIds: members
              .map((m) =>
                  m[SupabaseConstants.columnUserId] ??
                  m[SupabaseConstants.columnSupabaseId])
              .where((id) => id != null)
              .map((id) => id.toString())
              .where((id) => id.isNotEmpty && id != 'null')
              .toList(),
          memberNames: members
              .map((m) => (m[SupabaseConstants.name] ?? '').toString())
              .where((n) => n.isNotEmpty)
              .toList(),
          compatibilityScore: score,
        ));
      }

      bubbles.sort(_compareByLastActivity);
      return bubbles;
    } catch (e) {
      if (kDebugMode) {
        print('Error in BubbleRepository.getUserBubbles: $e');
      }
      rethrow;
    }
  }

  /// Get compatibility score for a bubble via RPC
  Future<int?> _getCompatibilityScore(String bubbleId) async {
    try {
      final result = await _client.rpc(
        'bubble_compatibility_score',
        params: {'p_bubble_id': bubbleId},
      );
      return result as int?;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching compatibility score for bubble $bubbleId: $e');
      }
      return null;
    }
  }

  Future<_BubbleMessagePreview?> _getLatestMessagePreview(
      String bubbleId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableMessages)
          .select('content, location_id, created_at')
          .eq(SupabaseConstants.columnBubbleId, bubbleId)
          .eq(SupabaseConstants.columnIsDeleted, false)
          .order(SupabaseConstants.columnCreatedAt, ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final createdAtRaw = response[SupabaseConstants.columnCreatedAt];
      if (createdAtRaw == null) {
        return null;
      }

      final content =
          (response[SupabaseConstants.columnContent] as String?)?.trim() ?? '';
      final hasLocation = response['location_id'] != null;

      return _BubbleMessagePreview(
        content: content.isNotEmpty
            ? content
            : (hasLocation ? 'Shared a place' : 'Tap to view locations'),
        createdAt: DateTime.parse(createdAtRaw as String),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching latest message preview for $bubbleId: $e');
      }
      return null;
    }
  }

  /// Get all members of a bubble
  Future<List<Map<String, dynamic>>> _getBubbleMembers(String bubbleId) async {
    try {
      final response = List<Map<String, dynamic>>.from(await _client.rpc(
        'get_bubble_members',
        params: {'p_bubble_id': bubbleId},
      ));

      if (response.isEmpty) {
        return [];
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching bubble members: $e');
      }
      return [];
    }
  }

  /// Get all locations for a bubble
  Future<List<LocationModel>> getBubbleLocations(String bubbleId) async {
    try {
      final response =
          await _client.from(SupabaseConstants.tableBubbleLocations).select('''
            ${SupabaseConstants.tableLocations}!inner(*)
          ''').eq(SupabaseConstants.columnBubbleId, bubbleId);

      final locationRows = (response as List)
          .map((item) => item[SupabaseConstants.tableLocations])
          .whereType<Map<String, dynamic>>()
          .toList();

      return await _locationService.processLocationsWithImages(locationRows);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching bubble locations: $e');
      }
      return [];
    }
  }

  /// Create a new bubble
  Future<String?> createBubble({
    required String name,
    required String createdBy,
    bool isPrivate = false,
  }) async {
    try {
      final bubbleId = await _client.rpc('create_bubble_with_member', params: {
        'p_name': name,
        'p_created_by': createdBy,
        'p_is_private': isPrivate,
      });
      return bubbleId;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating bubble: $e');
      }
      return null;
    }
  }

  /// Add a location to a bubble
  Future<bool> addLocationToBubble({
    required String bubbleId,
    required int locationId,
    required String addedBy,
    String? note,
  }) async {
    try {
      await _client.rpc('add_bubble_location', params: {
        'p_bubble_id': bubbleId,
        'p_location_id': locationId,
        'p_added_by': addedBy,
        'p_note': note,
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding location to bubble: $e');
      }
      return false;
    }
  }

  /// Get a single bubble by ID
  Future<Bubble?> getBubbleById(String bubbleId) async {
    try {
      // Get bubble details
      final bubbleResponse = await _client
          .from(SupabaseConstants.tableBubbles)
          .select()
          .eq(SupabaseConstants.columnBubbleId, bubbleId)
          .single();
      final bubbleCreatedAt =
          DateTime.parse(bubbleResponse[SupabaseConstants.columnCreatedAt]);

      final results = await Future.wait([
        _getBubbleMembers(bubbleId),
        getBubbleLocations(bubbleId),
        _getCompatibilityScore(bubbleId),
        _getLatestMessagePreview(bubbleId),
        _messagingHelper.getUnreadCount(bubbleId),
      ]);

      final members = results[0] as List<Map<String, dynamic>>;
      final locations = results[1] as List<LocationModel>;
      final score = results[2] as int?;
      final latestMessage = results[3] as _BubbleMessagePreview?;
      final unreadCount = results[4] as int;
      final lastActivityAt = latestMessage?.createdAt ?? bubbleCreatedAt;

      return Bubble(
        id: bubbleId,
        name: bubbleResponse[SupabaseConstants.columnName] ?? 'Unnamed Bubble',
        createdBy: bubbleResponse[SupabaseConstants.columnCreatedBy] ?? '',
        lastMessage: latestMessage?.content ?? 'Tap to view locations',
        lastMessageTime: _getTimeAgo(lastActivityAt),
        lastActivityAt: lastActivityAt,
        memberCount: members.length,
        memberAvatars: members
            .map((m) =>
                (m[SupabaseConstants.columnProfileImageUrl] ?? '') as String)
            .toList(),
        groupAvatar: members.isNotEmpty
            ? (members.first[SupabaseConstants.columnProfileImageUrl] ?? '')
            : '',
        isOnline: true,
        unreadCount: unreadCount,
        groupLocations: locations,
        description: 'Created ${_getTimeAgo(bubbleCreatedAt)}',
        memberIds: members
            .map((m) =>
                m[SupabaseConstants.columnUserId] ??
                m[SupabaseConstants.columnSupabaseId])
            .where((id) => id != null)
            .map((id) => id.toString())
            .where((id) => id.isNotEmpty && id != 'null')
            .toList(),
        memberNames: members
            .map((m) => (m[SupabaseConstants.name] ?? '').toString())
            .where((n) => n.isNotEmpty)
            .toList(),
        compatibilityScore: score,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error in BubbleRepository.getBubbleById: $e');
      }
      return null;
    }
  }

  /// Add a member to a bubble
  Future<bool> addMemberToBubble({
    required String bubbleId,
    required String userId,
  }) async {
    try {
      await _client.rpc('add_bubble_member', params: {
        'p_bubble_id': bubbleId,
        'p_user_id': userId,
      });

      // Send notification to the user about being added to the bubble
      final currentUser = SupabaseClientManager().currentUser;
      if (currentUser != null) {
        // Fetch bubble details to get bubble name
        final bubble = await getBubbleById(bubbleId);
        if (bubble != null) {
          // Fire and forget - don't wait for notification to complete
          PushNotificationService()
              .sendUserAddedToBubbleNotification(
            recipientUserId: userId,
            inviterUserId: currentUser.id,
            bubbleId: bubbleId,
            bubbleName: bubble.name,
          )
              .catchError((error) {
            if (kDebugMode) {
              print(
                  'BubbleHelper: Error sending user added notification: $error');
            }
            return false;
          });
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding member to bubble: $e');
      }
      return false;
    }
  }

  /// Remove a location from a bubble
  Future<bool> removeLocationFromBubble({
    required String bubbleId,
    required int locationId,
  }) async {
    try {
      await _client.rpc('remove_location_from_bubble', params: {
        'p_bubble_id': bubbleId,
        'p_location_id': locationId,
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error removing location from bubble: $e');
      }
      return false;
    }
  }

  /// Delete a bubble (creator-only via RLS).
  ///
  /// Returns `true` if the bubble row was deleted, `false` otherwise.
  Future<bool> deleteBubble({
    required String bubbleId,
  }) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableBubbles)
          .delete()
          .eq(SupabaseConstants.columnBubbleId, bubbleId)
          .select(SupabaseConstants.columnBubbleId);

      return (response as List).isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting bubble: $e');
      }
      return false;
    }
  }

  /// Rename a bubble (creator-only via RLS).
  ///
  /// Returns `true` if the bubble row was updated, `false` otherwise.
  Future<bool> renameBubble({
    required String bubbleId,
    required String name,
  }) async {
    try {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return false;

      final response = await _client
          .from(SupabaseConstants.tableBubbles)
          .update({SupabaseConstants.columnName: trimmed})
          .eq(SupabaseConstants.columnBubbleId, bubbleId)
          .select(SupabaseConstants.columnBubbleId);

      return (response as List).isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error renaming bubble: $e');
      }
      return false;
    }
  }

  /// Leave a bubble
  Future<bool> leaveBubble({
    required String bubbleId,
    required String userId,
  }) async {
    try {
      await _client.rpc('leave_bubble', params: {
        'p_bubble_id': bubbleId,
        'p_user_id': userId,
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error leaving bubble: $e');
      }
      return false;
    }
  }

  /// Get all saved locations from all members in a bubble
  Future<List<LocationModel>> getAllMemberLocations(String bubbleId) async {
    try {
      // First get all member IDs in the bubble
      final membersResponse = await _client
          .from(SupabaseConstants.tableBubbleMembers)
          .select(SupabaseConstants.columnUserId)
          .eq(SupabaseConstants.columnBubbleId, bubbleId);

      if ((membersResponse as List).isEmpty) {
        return [];
      }

      final memberIds = (membersResponse as List)
          .map((m) => m[SupabaseConstants.columnUserId].toString())
          .toList();

      // Use the location service to get all locations for these users
      return await _locationService.getLocationsByUserIds(memberIds);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching all member locations: $e');
      }
      return [];
    }
  }

  /// Get user location actions for a bubble
  Future<List<UserLocationActionModel>> getBubbleActivity(
      String bubbleId) async {
    try {
      final result = await _client.rpc('get_bubble_activity', params: {
        'p_bubble_id': bubbleId,
      });

      if (result == null) {
        return [];
      }

      final activities = (result as List)
          .map((json) => UserLocationActionModel.fromJson(json))
          .toList();

      if (kDebugMode) {
        print(
            'BubbleHelper: Loaded ${activities.length} activities for bubble $bubbleId');
      }

      return activities;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching bubble activity: $e');
      }
      return [];
    }
  }

  /// Get activity modifiers for all bubbles of a specific user
  /// Returns a map of bubbleId -> activity modifier
  Future<Map<String, num?>> getBubbleActivityModifiers(String userId) async {
    try {
      // Get all bubbles for the user with their activity modifiers
      final response =
          await _client.from(SupabaseConstants.tableBubbleMembers).select('''
            ${SupabaseConstants.columnBubbleId},
            ${SupabaseConstants.tableBubbles}!inner(
              ${SupabaseConstants.columnBubbleId},
              ${SupabaseConstants.columnActivity}
            )
          ''').eq(SupabaseConstants.columnUserId, userId);

      if ((response as List).isEmpty) {
        return {};
      }

      final Map<String, num?> modifiers = {};
      for (var item in response as List) {
        final bubble = item[SupabaseConstants.tableBubbles];
        final bubbleId = bubble[SupabaseConstants.columnBubbleId] as String;
        final activity = bubble[SupabaseConstants.columnActivity] as num?;
        modifiers[bubbleId] = activity;
      }

      return modifiers;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching bubble activity modifiers: $e');
      }
      return {};
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

  int _compareByLastActivity(Bubble a, Bubble b) {
    final aTime = a.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.lastActivityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  }
}

class _BubbleMessagePreview {
  final String content;
  final DateTime createdAt;

  const _BubbleMessagePreview({
    required this.content,
    required this.createdAt,
  });
}
