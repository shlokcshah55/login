import 'package:flutter/foundation.dart';
import 'package:login/models/chat_group_model.dart';
import 'package:login/models/locations.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/supabase/helpers/location.dart';
import 'package:login/supabase/constants.dart';

/// Repository for bubble-related operations
class BubbleHelper {
  final _client = SupabaseClientManager().client;
  final _locationService = LocationHelper();

  /// Get all bubbles for the current user
  Future<List<ChatGroupModel>> getUserBubbles(String userId) async {
    try {
      // Get bubbles where user is a member
      final response = await _client
          .from(SupabaseConstants.tableBubbleMembers)
          .select('''
            ${SupabaseConstants.columnBubbleId},
            ${SupabaseConstants.tableBubbles}!inner(
              ${SupabaseConstants.columnBubbleId},
              ${SupabaseConstants.columnName},
              ${SupabaseConstants.columnCreatedBy},
              ${SupabaseConstants.columnCreatedAt},
              ${SupabaseConstants.columnIsPrivate}
            )
          ''')
          .eq(SupabaseConstants.columnUserId, userId);

      if ((response as List).isEmpty) {
        return [];
      }

      List<ChatGroupModel> bubbles = [];

      for (var item in response as List) {
        final bubble = item[SupabaseConstants.tableBubbles];
        final bubbleId = bubble[SupabaseConstants.columnBubbleId];
        
        // Get member count and avatars
        final members = await _getBubbleMembers(bubbleId);
        
        // Get locations for this bubble
        final locations = await _getBubbleLocations(bubbleId);
        
        // Create ChatGroupModel
        bubbles.add(ChatGroupModel(
          id: bubbleId,
          name: bubble[SupabaseConstants.columnName] ?? 'Unnamed Bubble',
          lastMessage: 'Tap to view locations',
          lastMessageTime: _getTimeAgo(DateTime.parse(bubble[SupabaseConstants.columnCreatedAt])),
          memberCount: members.length,
          memberAvatars: members.map((m) => (m[SupabaseConstants.columnProfileImageUrl] ?? '') as String).toList(),
          groupAvatar: members.isNotEmpty ? (members.first[SupabaseConstants.columnProfileImageUrl] ?? '') : '',
          isOnline: true,
          unreadCount: 0,
          groupLocations: locations,
          description: 'Created ${_getTimeAgo(DateTime.parse(bubble[SupabaseConstants.columnCreatedAt]))}',
          memberIds: members.map((m) => m[SupabaseConstants.columnSupabaseId].toString()).toList(),
        ));
      }

      return bubbles;
    } catch (e) {
      if (kDebugMode) {
        print('Error in BubbleRepository.getUserBubbles: $e');
      }
      rethrow;
    }
  }

  /// Get all members of a bubble
  Future<List<Map<String, dynamic>>> _getBubbleMembers(String bubbleId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableBubbleMembers)
          .select('''
            ${SupabaseConstants.columnUserId},
            ${SupabaseConstants.tableUsers}!inner(
              ${SupabaseConstants.columnSupabaseId},
              ${SupabaseConstants.name},
              ${SupabaseConstants.columnProfileImageUrl}
            )
          ''')
          .eq(SupabaseConstants.columnBubbleId, bubbleId);

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List)
          .map((item) => item[SupabaseConstants.tableUsers] as Map<String, dynamic>)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching bubble members: $e');
      }
      return [];
    }
  }

  /// Get all locations for a bubble
  Future<List<LocationModel>> _getBubbleLocations(String bubbleId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableBubbleLocations)
          .select('''
            ${SupabaseConstants.columnLocationId},
            ${SupabaseConstants.tableLocations}!inner(
              ${SupabaseConstants.columnLocationId},
              ${SupabaseConstants.columnName},
              ${SupabaseConstants.columnVicinity},
              ${SupabaseConstants.columnLat},
              ${SupabaseConstants.columnLng},
              ${SupabaseConstants.columnCreatedAt},
              ${SupabaseConstants.columnPhoneNumber},
              ${SupabaseConstants.columnCuisine},
              ${SupabaseConstants.columnRating},
              ${SupabaseConstants.columnUserRatingsTotal},
              ${SupabaseConstants.columnPriceLevel},
              ${SupabaseConstants.columnPhotoReference},
              ${SupabaseConstants.columnSavedCount}
            )
          ''')
          .eq(SupabaseConstants.columnBubbleId, bubbleId);

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List)
          .map((item) {
            final location = item[SupabaseConstants.tableLocations];
            return LocationModel(
              locationId: location[SupabaseConstants.columnLocationId],
              name: location[SupabaseConstants.columnName] ?? '',
              vicinity: location[SupabaseConstants.columnVicinity] ?? '',
              lat: (location[SupabaseConstants.columnLat] as num?)?.toDouble() ?? 0.0,
              lng: (location[SupabaseConstants.columnLng] as num?)?.toDouble() ?? 0.0,
              createdAt: DateTime.parse(location[SupabaseConstants.columnCreatedAt]),
              phoneNumber: location[SupabaseConstants.columnPhoneNumber],
              cuisine: location[SupabaseConstants.columnCuisine],
              rating: (location[SupabaseConstants.columnRating] as num?)?.toDouble(),
              userRatingsTotal: location[SupabaseConstants.columnUserRatingsTotal],
              priceLevel: location[SupabaseConstants.columnPriceLevel],
              photoReference: location[SupabaseConstants.columnPhotoReference],
              savedCount: location[SupabaseConstants.columnSavedCount],
            );
          })
          .toList();
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
  Future<ChatGroupModel?> getBubbleById(String bubbleId) async {
    try {
      // Get bubble details
      final bubbleResponse = await _client
          .from(SupabaseConstants.tableBubbles)
          .select()
          .eq(SupabaseConstants.columnBubbleId, bubbleId)
          .single();

      // Get member count and avatars
      final members = await _getBubbleMembers(bubbleId);
      
      // Get locations for this bubble
      final locations = await _getBubbleLocations(bubbleId);
      
      // Create ChatGroupModel
      return ChatGroupModel(
        id: bubbleId,
        name: bubbleResponse[SupabaseConstants.columnName] ?? 'Unnamed Bubble',
        lastMessage: 'Tap to view locations',
        lastMessageTime: _getTimeAgo(DateTime.parse(bubbleResponse[SupabaseConstants.columnCreatedAt])),
        memberCount: members.length,
        memberAvatars: members.map((m) => (m[SupabaseConstants.columnProfileImageUrl] ?? '') as String).toList(),
        groupAvatar: members.isNotEmpty ? (members.first[SupabaseConstants.columnProfileImageUrl] ?? '') : '',
        isOnline: true,
        unreadCount: 0,
        groupLocations: locations,
        description: 'Created ${_getTimeAgo(DateTime.parse(bubbleResponse[SupabaseConstants.columnCreatedAt]))}',
        memberIds: members.map((m) => m[SupabaseConstants.columnSupabaseId].toString()).toList(),
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
      await _client
          .from(SupabaseConstants.tableBubbleLocations)
          .delete()
          .eq(SupabaseConstants.columnBubbleId, bubbleId)
          .eq(SupabaseConstants.columnLocationId, locationId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error removing location from bubble: $e');
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
      await _client
          .from(SupabaseConstants.tableBubbleMembers)
          .delete()
          .eq(SupabaseConstants.columnBubbleId, bubbleId)
          .eq(SupabaseConstants.columnUserId, userId);
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

  /// Get activity modifiers for all bubbles of a specific user
  /// Returns a map of bubbleId -> activity modifier
  Future<Map<String, num?>> getBubbleActivityModifiers(String userId) async {
    try {
      // Get all bubbles for the user with their activity modifiers
      final response = await _client
          .from(SupabaseConstants.tableBubbleMembers)
          .select('''
            ${SupabaseConstants.columnBubbleId},
            ${SupabaseConstants.tableBubbles}!inner(
              ${SupabaseConstants.columnBubbleId},
              ${SupabaseConstants.columnActivity}
            )
          ''')
          .eq(SupabaseConstants.columnUserId, userId);

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
}