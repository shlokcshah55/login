import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:login/supabase/helpers/location.dart';
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

      return response as Map<String, dynamic>?;
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

  /// Get most commonly used tags across locations based on location_tags count
  /// Returns tags with their usage count
  Future<List<Map<String, dynamic>>> getPopularTags(
      {String? tagType, int limit = 10}) async {
    try {
      // Query to count how many times each tag is used in location_tags
      var query = _client.from(SupabaseConstants.tableLocationTags).select('''
            ${SupabaseConstants.columnTagId},
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

      // Count occurrences of each tag
      final Map<int, Map<String, dynamic>> tagCounts = {};
      for (var item in response as List) {
        final tagId = item[SupabaseConstants.columnTagId] as int;
        final tag =
            item[SupabaseConstants.tableTags] as Map<String, dynamic>;

        if (tagCounts.containsKey(tagId)) {
          tagCounts[tagId]!['usage_count'] =
              (tagCounts[tagId]!['usage_count'] as int) + 1;
        } else {
          tagCounts[tagId] = {
            'tag_id': tag[SupabaseConstants.columnTagId],
            'text': tag[SupabaseConstants.columnText],
            'prompt_description': tag[SupabaseConstants.columnPromptDescription],
            'tag_type': tag[SupabaseConstants.columnTagType],
            'usage_count': 1,
          };
        }
      }

      // Sort by usage count and limit
      final sortedTags = tagCounts.values.toList()
        ..sort((a, b) =>
            (b['usage_count'] as int).compareTo(a['usage_count'] as int));

      return sortedTags.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting popular tags: $e');
      }
      return [];
    }
  }

  /// Get tags used by the most locations
  /// Similar to getPopularTags but returns distinct location count
  Future<List<Map<String, dynamic>>> getPopularTagsByLocations(
      {String? tagType, int limit = 10}) async {
    try {
      var query = _client.from(SupabaseConstants.tableLocationTags).select('''
            ${SupabaseConstants.columnTagId},
            ${SupabaseConstants.columnLocationId},
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

      // Count distinct locations for each tag
      final Map<int, Map<String, dynamic>> tagLocationCounts = {};
      for (var item in response as List) {
        final tagId = item[SupabaseConstants.columnTagId] as int;
        final locationId = item[SupabaseConstants.columnLocationId] as int;
        final tag =
            item[SupabaseConstants.tableTags] as Map<String, dynamic>;

        if (tagLocationCounts.containsKey(tagId)) {
          // Add location to the set of unique locations
          (tagLocationCounts[tagId]!['location_ids'] as Set<int>)
              .add(locationId);
        } else {
          tagLocationCounts[tagId] = {
            'tag_id': tag[SupabaseConstants.columnTagId],
            'text': tag[SupabaseConstants.columnText],
            'prompt_description': tag[SupabaseConstants.columnPromptDescription],
            'tag_type': tag[SupabaseConstants.columnTagType],
            'location_ids': {locationId},
          };
        }
      }

      // Convert to list with location count
      final tagList = tagLocationCounts.values.map((tag) {
        return {
          'tag_id': tag['tag_id'],
          'text': tag['text'],
          'prompt_description': tag['prompt_description'],
          'tag_type': tag['tag_type'],
          'location_count': (tag['location_ids'] as Set<int>).length,
        };
      }).toList();

      // Sort by location count and limit
      tagList.sort((a, b) =>
          (b['location_count'] as int).compareTo(a['location_count'] as int));

      return tagList.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting popular tags by locations: $e');
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

  Future<List<Map<String, dynamic>>> getUserTagScores(String userId) async {
    try {
      print("Getting user tag scores for user: $userId");

      final response = await _client.rpc('get_user_tag_scores', params: {
        'p_user_id': userId,
      });

      print("User tag scores response: $response");

      if (response is List) {
      return response
          .whereType<Map<String, dynamic>>() 
          .toList();
    } else {
      return [];
    }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user tag scores: $e');
      }
      return [];
    }
  }

  /// Returns a weight in the range 0.0 - 1.0 where more interactions -> lower weight.
  ///
  /// Uses an inverse-log style decay so the weight decreases slowly at first
  /// (the first ~50 interactions keep the weight near 0.9-1.0) and then
  /// decays more for larger counts. Adjust the `decayCoefficient` to
  /// tune the curve.
  Future<double> getInteractionWeight(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableUserLocationActions)
          .select()
          .eq(SupabaseConstants.columnUserId, userId);

      final int count = (response as List).length;

      // TODO:
      // Tweak this formula as needs be, currently uses inverse-log style: weight = 1 / (1 + c * ln(1 + n))
      const double decayCoefficient = 0.0135;
      final double weight = 1.0 / (1.0 + decayCoefficient * log(1 + count));

      // Ensure numeric bounds [0.0, 1.0]
      return weight.clamp(0.0, 1.0);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting interaction weight: $e');
      }
      return 1.0; 
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

  // Value is how much we want to adjust the affinity by, tagAffinities is a map of tagID to affinity weight that is affecting that one
  Future<bool> updateUserTagAffinityByWeight(String userID, int value, Map<String,double> tagAffinities, {required String action, int? locationId}) async {
    try {
      var user_tags = await getUserTagScores(userID);
      var tagIds = tagAffinities.keys.toList();

      // Filter to only relevant tags
      user_tags = user_tags.where((map) {
        return tagIds.contains(map[SupabaseConstants.columnTagId]);
      }).toList(); 

      var weight = await getInteractionWeight(userID);
      List<Map<String, dynamic>> updatedAffinities = [];

      // Get current timestamp in ISO 8601 format
      final timestamp = DateTime.now().toUtc().toIso8601String();

      for (final map in user_tags) {
        final currentAffinity = (map[SupabaseConstants.columnUserTagAffinity] as num).toDouble();
        final locationAffinity = tagAffinities[map[SupabaseConstants.columnTagId]]!;

        // Value is maximum the affinity should shift by
        // Weight scales it down based on user interactions [0, 1]
        // Delta is how much to shift the affinity based on the location [-1, 1]
        final delta = value * weight * ((locationAffinity - 50) / 50);
        final computedAffinity = currentAffinity + delta;

        // Build evidence object for this update
        final evidence = {
          'action': action,
          'location_id': locationId,
          'timestamp': timestamp,
          'value': value,
          'delta': delta,
          'weight': weight,
        };

        updatedAffinities.add({
          SupabaseConstants.columnTagId: map[SupabaseConstants.columnTagId],
          SupabaseConstants.columnUserTagAffinity: computedAffinity,
          SupabaseConstants.columnUserTagEvidence: evidence,
        });
      }

      // Convert updatedAffinities to JSONB format for RPC
      final jsonbAffinities = updatedAffinities.map((item) => {
        SupabaseConstants.columnTagId: item[SupabaseConstants.columnTagId],
        SupabaseConstants.columnUserTagAffinity: item[SupabaseConstants.columnUserTagAffinity],
        SupabaseConstants.columnUserTagEvidence: item[SupabaseConstants.columnUserTagEvidence],
      }).toList();
      

      await _client.rpc('update_user_tag_affinity', params: {
        'p_user_id': userID,
        'p_tag_affinities': jsonbAffinities,
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user tag affinity by weight: $e');
      }
      return false;
    }

  }

  Future<bool> updateUserTagsSharing(String userId, int locationID) async {
    final LocationHelper locationHelper = LocationHelper();
    List<Map<String, dynamic>> tags = await locationHelper.getLocationTags(locationID, "vibe");
    
    
    Map<String, double> tagMap = {};
    for (var tag in tags) {
      tagMap[tag[SupabaseConstants.columnTagId].toString()] = (tag[SupabaseConstants.columnScore] as num).toDouble();
    }
    // Set sharing score to be 10
    return updateUserTagAffinityByWeight(userId, 10, tagMap, action: 'shared', locationId: locationID);
  }

  Future<bool> updateUserTagsSaving(String userId, int locationID) async {
    final LocationHelper locationHelper = LocationHelper();
    List<Map<String, dynamic>> tags = await locationHelper.getLocationTags(locationID, "vibe");
    
    Map<String, double> tagMap = {};
    for (var tag in tags) {
      tagMap[tag[SupabaseConstants.columnTagId].toString()] = (tag[SupabaseConstants.columnScore] as num).toDouble();
    }
    // Set saving score to be 5
    return updateUserTagAffinityByWeight(userId, 5, tagMap, action: 'saved', locationId: locationID);
  }

  Future<bool> updateUserTagsDismissGavel(String userId, int locationID) async {
    final LocationHelper locationHelper = LocationHelper();
    List<Map<String, dynamic>> tags = await locationHelper.getLocationTags(locationID, "vibe");

    Map<String, double> tagMap = {};
    for (var tag in tags) {
      tagMap[tag[SupabaseConstants.columnTagId].toString()] = (tag[SupabaseConstants.columnScore] as num).toDouble();
    }
    return updateUserTagAffinityByWeight(userId, -5, tagMap, action: 'disliked', locationId: locationID);
  }

  
  Future<bool> updateUserTagsPhotos(String userID, List<String> tags) async {
    Map<String, double> tagMap = {};
    for (var tag in tags) {
      tagMap[tag] = 80;
    }
    print("updating user tags based on vibe photos");
    return updateUserTagAffinityByWeight(userID, 5, tagMap, action: 'initialisation vibes');
  }


  // TODO:
  // Future<bool> updateUserTagsRating(String userId, int locationID) async
  // Future<bool> updateUserTagsMagicSearch(String userId, int locationID) async
  // Future<bool> updateUserTagsSpiceTolerance(String userId, int spiceTolerance) async {


}
