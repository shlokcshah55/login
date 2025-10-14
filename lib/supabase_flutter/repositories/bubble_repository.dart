import 'package:flutter/foundation.dart';
import 'package:login/models/chat_group_model.dart';
import 'package:login/supabase_flutter/models/location_model.dart';
import 'package:login/supabase_flutter/supabase_client.dart';
import 'package:login/supabase_flutter/services/supabase_location_service.dart';

/// Repository for bubble-related operations
class BubbleRepository {
  final _client = SupabaseClientManager().client;
  final _locationService = SupabaseLocationService();

  /// Get all bubbles for the current user
  Future<List<ChatGroupModel>> getUserBubbles(String userId) async {
    try {
      // Get bubbles where user is a member
      final response = await _client
          .from('bubble_members')
          .select('''
            bubble_id,
            bubbles!inner(
              bubble_id,
              name,
              created_by,
              created_at,
              is_private
            )
          ''')
          .eq('user_id', userId);

      if ((response as List).isEmpty) {
        return [];
      }

      List<ChatGroupModel> bubbles = [];
      
      for (var item in response as List) {
        final bubble = item['bubbles'];
        final bubbleId = bubble['bubble_id'];
        
        // Get member count and avatars
        final members = await _getBubbleMembers(bubbleId);
        
        // Get locations for this bubble
        final locations = await _getBubbleLocations(bubbleId);
        
        // Create ChatGroupModel
        bubbles.add(ChatGroupModel(
          id: bubbleId,
          name: bubble['name'] ?? 'Unnamed Bubble',
          lastMessage: 'Tap to view locations',
          lastMessageTime: _getTimeAgo(DateTime.parse(bubble['created_at'])),
          memberCount: members.length,
          memberAvatars: members.map((m) => (m['profile_image_url'] ?? '') as String).toList(),
          groupAvatar: members.isNotEmpty ? (members.first['profile_image_url'] ?? '') : '',
          isOnline: true,
          unreadCount: 0,
          groupLocations: locations,
          description: 'Created ${_getTimeAgo(DateTime.parse(bubble['created_at']))}',
          memberIds: members.map((m) => m['supabase_id'].toString()).toList(),
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
          .from('bubble_members')
          .select('''
            user_id,
            users!inner(
              supabase_id,
              name,
              profile_image_url
            )
          ''')
          .eq('bubble_id', bubbleId);

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List)
          .map((item) => item['users'] as Map<String, dynamic>)
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
          .from('bubble_locations')
          .select('''
            location_id,
            locations!inner(
              location_id,
              name,
              vicinity,
              lat,
              lng,
              created_at,
              phone_number,
              cuisine,
              rating,
              user_ratings_total,
              price_level,
              photo_reference,
              saved_count
            )
          ''')
          .eq('bubble_id', bubbleId);

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List)
          .map((item) {
            final location = item['locations'];
            return LocationModel(
              locationId: location['location_id'],
              name: location['name'] ?? '',
              vicinity: location['vicinity'] ?? '',
              lat: (location['lat'] as num?)?.toDouble() ?? 0.0,
              lng: (location['lng'] as num?)?.toDouble() ?? 0.0,
              createdAt: DateTime.parse(location['created_at']),
              phoneNumber: location['phone_number'],
              cuisine: location['cuisine'],
              rating: (location['rating'] as num?)?.toDouble(),
              userRatingsTotal: location['user_ratings_total'],
              priceLevel: location['price_level'],
              photoReference: location['photo_reference'],
              savedCount: location['saved_count'],
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
      final response = await _client
          .from('bubbles')
          .insert({
            'name': name,
            'created_by': createdBy,
            'is_private': isPrivate,
          })
          .select()
          .single();

      final bubbleId = response['bubble_id'];

      // Add creator as a member
      await _client.from('bubble_members').insert({
        'bubble_id': bubbleId,
        'user_id': createdBy,
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
      await _client.from('bubble_locations').insert({
        'bubble_id': bubbleId,
        'location_id': locationId,
        'added_by': addedBy,
        'note': note,
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
          .from('bubbles')
          .select()
          .eq('bubble_id', bubbleId)
          .single();

      // Get member count and avatars
      final members = await _getBubbleMembers(bubbleId);
      
      // Get locations for this bubble
      final locations = await _getBubbleLocations(bubbleId);
      
      // Create ChatGroupModel
      return ChatGroupModel(
        id: bubbleId,
        name: bubbleResponse['name'] ?? 'Unnamed Bubble',
        lastMessage: 'Tap to view locations',
        lastMessageTime: _getTimeAgo(DateTime.parse(bubbleResponse['created_at'])),
        memberCount: members.length,
        memberAvatars: members.map((m) => (m['profile_image_url'] ?? '') as String).toList(),
        groupAvatar: members.isNotEmpty ? (members.first['profile_image_url'] ?? '') : '',
        isOnline: true,
        unreadCount: 0,
        groupLocations: locations,
        description: 'Created ${_getTimeAgo(DateTime.parse(bubbleResponse['created_at']))}',
        memberIds: members.map((m) => m['supabase_id'].toString()).toList(),
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
      await _client.from('bubble_members').insert({
        'bubble_id': bubbleId,
        'user_id': userId,
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
          .from('bubble_locations')
          .delete()
          .eq('bubble_id', bubbleId)
          .eq('location_id', locationId);
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
          .from('bubble_members')
          .delete()
          .eq('bubble_id', bubbleId)
          .eq('user_id', userId);
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
          .from('bubble_members')
          .select('user_id')
          .eq('bubble_id', bubbleId);

      if ((membersResponse as List).isEmpty) {
        return [];
      }

      final memberIds = (membersResponse as List)
          .map((m) => m['user_id'].toString())
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