import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../supabase_client.dart';

/// Service for handling Supabase tags operations
class TagsHelper {
  final SupabaseClient _client = SupabaseClientManager().client;  

  /// Get all tags, optionally filtered by type
  Future<List<Map<String, dynamic>>> getAllTags({String? tagType}) async {
    try {
      var query = _client
          .from(SupabaseConstants.tableTags)
          .select();

      if (tagType != null) {
        query = query.eq(SupabaseConstants.columnTagType, tagType);
      }

      final response = await query.order(SupabaseConstants.columnText, ascending: true);

      if (kDebugMode) {
        print('Tags response: $response');
      }

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all tags: $e');
      }
      return [];
    }
  }

  /// Get tags of a specific type
  Future<List<Map<String, dynamic>>> getTagsByType(String tagType) async {
    return getAllTags(tagType: tagType);
  }

  /// Get all dietary requirement tags
  Future<List<Map<String, dynamic>>> getDietaryRequirementTags() async {
    return await getTagsByType(SupabaseConstants.tagTypeDietaryRequirement);
  }

  /// Get all vibe tags
  Future<List<Map<String, dynamic>>> getVibeTags() async {
    return await getTagsByType(SupabaseConstants.tagTypeVibe);
  }

  /// Get all cuisine tags
  Future<List<Map<String, dynamic>>> getCuisineTags() async {
    return await getTagsByType(SupabaseConstants.tagTypeCuisine);
  }

  /// Get a single tag by its ID
  Future<Map<String, dynamic>?> getTagById(int tagId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableTags)
          .select()
          .eq(SupabaseConstants.columnTagId, tagId)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting tag by ID: $e');
      }
      return null;
    }
  }

  /// Search tags by text, optionally filtered by type
  Future<List<Map<String, dynamic>>> searchTags(String query,
      {String? tagType}) async {
    try {
      if (query.isEmpty) return [];

      var supabaseQuery = _client
          .from(SupabaseConstants.tableTags)
          .select()
          .ilike(SupabaseConstants.columnText, '%$query%')
          .order(SupabaseConstants.columnText, ascending: true);


      final response = await supabaseQuery;

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching tags: $e');
      }
      return [];
    }
  }

  /// Get tags used by the most users
  Future<List<Map<String, dynamic>>> getPopularTagsByUsers(
      {String? tagType, int limit = 10}) async {
    try {
      var query = _client.from(SupabaseConstants.tableUserTags).select('''
            ${SupabaseConstants.columnTagId},
            ${SupabaseConstants.columnUserId},
            ${SupabaseConstants.tableTags}!inner(
              ${SupabaseConstants.columnTagId},
              ${SupabaseConstants.columnText},
              ${SupabaseConstants.columnPromptDescription},
              ${SupabaseConstants.columnTagType}
            )
          ''');

      if (tagType != null) {
        query = query.eq(
            '${SupabaseConstants.tableTags}.${SupabaseConstants.columnTagType}',
            tagType);
      }

      final response = await query;

      if ((response as List).isEmpty) {
        return [];
      }

      // Count distinct users for each tag
      final Map<int, Map<String, dynamic>> tagUserCounts = {};
      for (var item in response as List) {
        final tagId = item[SupabaseConstants.columnTagId] as int;
        final userId = item[SupabaseConstants.columnUserId] as String;
        final tag =
            item[SupabaseConstants.tableTags] as Map<String, dynamic>;

        if (tagUserCounts.containsKey(tagId)) {
          // Add user to the set of unique users
          (tagUserCounts[tagId]!['user_ids'] as Set<String>).add(userId);
        } else {
          tagUserCounts[tagId] = {
            'tag_id': tag[SupabaseConstants.columnTagId],
            'text': tag[SupabaseConstants.columnText],
            'prompt_description': tag[SupabaseConstants.columnPromptDescription],
            'tag_type': tag[SupabaseConstants.columnTagType],
            'user_ids': {userId},
          };
        }
      }

      // Convert to list with user count
      final tagList = tagUserCounts.values.map((tag) {
        return {
          'tag_id': tag['tag_id'],
          'text': tag['text'],
          'prompt_description': tag['prompt_description'],
          'tag_type': tag['tag_type'],
          'user_count': (tag['user_ids'] as Set<String>).length,
        };
      }).toList();

      // Sort by user count and limit
      tagList.sort(
          (a, b) => (b['user_count'] as int).compareTo(a['user_count'] as int));

      return tagList.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting popular tags by users: $e');
      }
      return [];
    }
  }

  // Initalise all vibe tags for a user
  Future<bool> initializeVibeTagsForUser(String userId) async {
   try {
      await _client.rpc('initialize_vibe_tags_for_user', params: {
        'p_user_id': userId,
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing vibe tags for user: $e');
      }
      return false;
    }
  }

  // Future<bool> updateUserTagsPhotos(String userID, List<String> tags) async {
  //   Map<String, double> tagMap = {};
  //   for (var tag in tags) {
  //     tagMap[tag] = 80;
  //   }
  //   print("updating user tags based on vibe photos");
  //   return updateUserTagAffinityByWeight(userID, 5, tagMap, action: 'initialisation vibes');
  // }


  // TODO:
  // Future<bool> updateUserTagsRating(String userId, int locationID) async
  // Future<bool> updateUserTagsMagicSearch(String userId, int locationID) async
  // Future<bool> updateUserTagsSpiceTolerance(String userId, int spiceTolerance) async {


}
