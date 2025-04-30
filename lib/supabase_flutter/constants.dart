/// Supabase table and column name constants
class SupabaseConstants {
  // Table names
  static const String tableLocations = 'locations';
  static const String tableVideos = 'videos';
  static const String tableUserFriends = 'user_friends';
  static const String tableUserLocationActions = 'user_location_actions';
  static const String tableLocationPopularityApp = 'location_popularity_app';
  static const String tableLocationPopularitySocial = 'location_popularity_social';

  // Column names - locations
  static const String columnLocationId = 'location_id';
  static const String columnName = 'name';
  static const String columnAddress = 'address';
  static const String columnLat = 'lat';
  static const String columnLng = 'lng';
  static const String columnCreatedAt = 'created_at';
  static const String columnPhoneNumber = 'phone_number';

  // Column names - videos
  static const String columnVideoId = 'video_id';
  static const String columnUserId = 'user_id';
  static const String columnPlatform = 'platform';
  static const String columnUrl = 'url';
  static const String columnExtractedLocationId = 'extracted_location_id';
  static const String columnPostedAt = 'posted_at';

  // Column names - user_friends
  static const String columnFriendId = 'friend_id';

  // Column names - user_location_actions
  static const String columnActionId = 'action_id';
  static const String columnAction = 'action';
  static const String columnSourceVideoId = 'source_video_id';
  static const String columnSavedMethod = 'saved_method';

  // Column names - location_popularity_app
  static const String columnSavesCount = 'saves_count';
  static const String columnLikesCount = 'likes_count';
  static const String columnUpdatedAt = 'updated_at';

  // Column names - location_popularity_social
  static const String columnMentionCount = 'mention_count';
  static const String columnLastScanned = 'last_scanned';

  // Enum values - action_type
  static const String actionSave = 'save';
  static const String actionLike = 'like';
  static const String actionSharedVideo = 'shared_video';

  // Enum values - saved_method
  static const String savedMethodTikTok = 'tiktok';
  static const String savedMethodInApp = 'in-app';
}