/// Supabase table and column name constants
class SupabaseConstants {
  // Table names
  static const String tableLocations = 'locations';
  static const String tableVideos = 'videos';
  static const String tableUserFriends = 'user_friends';
  static const String tableUserLocationActions = 'user_location_actions';
  static const String tableLocationPopularityApp = 'location_popularity_app';
  static const String tableLocationPopularitySocial =
      'location_popularity_social';
  static const String tableUsers = 'users';
  static const String tableBubbles = 'bubbles';
  static const String tableBubbleMembers = 'bubble_members';
  static const String tableBubbleLocations = 'bubble_locations';
  static const String tableTags = 'tags';
  static const String tableLocationTags = 'location_tags';
  static const String tableUserTags = 'user_tag_affinities';
  static const String tableUserTagAffinities = 'user_tag_affinities';

  // Column names - users
  static const String columnSupabaseId = 'supabase_id';
  static const String name = 'name';
  static const String columnEmail = 'email';
  static const String columnBio = 'bio';
  static const String columnProfileImageUrl = 'profile_image_url';
  static const String columnWizardCompleted = 'wizard_completed';
  static const String columnUsername = 'username';


  // Column names - locations
  static const String columnLocationId = 'location_id';
  static const String columnName = 'name';
  static const String columnVicinity = 'vicinity';
  static const String columnLat = 'lat';
  static const String columnLng = 'lng';
  static const String columnCreatedAt = 'created_at';
  static const String columnPhoneNumber = 'phone_number';
  static const String columnCuisine = 'cuisine';
  static const String columnRating = 'rating';
  static const String columnUserRatingsTotal = 'user_ratings_total';
  static const String columnPriceLevel = 'price_level';
  static const String columnPhotoReference = 'photo_reference';
  static const String columnSavedCount = 'saved_count';
  static const String columnGooglePlaceId = 'google_place_id';
  static const String columnBusinessStatus = 'business_status';
  static const String columnEditorialSummary = 'editorial_summary';
  static const String columnWebsite = 'website';
  static const String columnInternationalPhoneNumber = 'international_phone_number';
  static const String columnTypes = 'types';
  static const String columnOpeningHoursText = 'opening_hours_text';
  static const String columnOpeningHoursPeriods = 'opening_hours_periods';
  static const String columnOpenNow = 'open_now';
  static const String columnCuisineDetected = 'cuisine_detected';
  static const String columnCuisineSource = 'cuisine_source';
  static const String columnCuisinePrimary = 'cuisine_primary';
  static const String columnTopReviewLanguage = 'top_review_language';
  static const String columnTopLanguageShare = 'top_language_share';
  static const String columnReviewLanguageCountsJson = 'review_language_counts_json';
  static const String columnIsOpenLate = 'is_open_late';
  static const String columnIsOpenEarly = 'is_open_early';
  static const String columnIsSundayOpen = 'is_sunday_open';
  static const String columnPriceBucket = 'price_bucket';
  static const String columnLogReviews = 'log_reviews';
  static const String columnDerivedAttributes = 'derived_attributes';
  static const String columnDataVersion = 'data_version';
  static const String columnIngestedAt = 'ingested_at';

  // Column names - videos
  static const String columnVideoId = 'video_id';
  static const String columnPlatform = 'platform';
  static const String columnUrl = 'url';
  static const String columnExtractedLocationId = 'extracted_location_id';

  // Column names - user_friends
  static const String columnFolloweeId = 'followee_id';
  static const String columnFollowerId = 'follower_id';
  static const String columnStatus = 'status';
  static const String columnInfluence = 'influence';

  // Column names - user_location_actions
  static const String columnActionId = 'action_id';
  static const String columnAction = 'action';
  static const String columnSourceVideoUrl = 'source_video_url';
  static const String columnSavedMethod = 'saved_method';
  static const String columnPreference = 'preference';
  static const String columnUserId = 'user_id';
  static const String columnAcked = 'acked';

  // Column names - location_popularity_app
  static const String columnSavesCount = 'saves_count';
  static const String columnDislikeCount = 'dislikes_count';
  static const String columnUpdatedAt = 'updated_at';

  // Column names - location_popularity_social
  static const String columnMentionCount = 'mention_count';
  static const String columnLastScanned = 'last_scanned';

  // Column names - bubbles
  static const String columnBubbleId = 'bubble_id';
  static const String columnCreatedBy = 'created_by';
  static const String columnIsPrivate = 'is_private';
  static const String columnActivity = 'activity';

  // Column names - bubble_members
  static const String columnId = 'id';
  static const String columnAddedAt = 'added_at';

  // Column names - bubble_locations
  static const String columnBubbleLocationId = 'bubble_location_id';
  static const String columnAddedBy = 'added_by';
  static const String columnNote = 'note';

  // Column names - tags
  static const String columnTagId = 'tag_id';
  static const String columnText = 'text';
  static const String columnPromptDescription = 'prompt_description';
  static const String columnTagType = 'tag_type';
  static const String columnColour = 'Colour';
  // Column names - location_tags
  // columnId is already defined in bubble_members
  // columnLocationId and columnTagId are already defined above
  static const String columnScore = 'score';

  // Column names - user_tags
  // columnId, columnUserId, and columnTagId are already defined above

  // Enum values - action_type
  static const String actionSave = 'save';
  static const String actionSharedVideo = 'shared_video';
  static const String actionDislike = 'dislike';

  // Enum values - saved_method
  static const String savedMethodTikTok = 'tiktok';
  static const String savedMethodInApp = 'in-app';

  // Enum values - relationship_status
  static const String relationshipStatusAccepted = 'accepted';
  static const String relationshipStatusPending = 'pending';
  static const String relationshipStatusBlocked = 'blocked';

  // Enum values - tag_type
  static const String tagTypeDietaryRequirement = 'dietary_requirement';
  static const String tagTypeVibe = 'vibe';
  static const String tagTypeCuisine = 'cuisine';

  static const String supabaseStorageBucketProfileImages =
      'profile_photos';

  static const String columnUserTagAffinity = 'affinity';
  static const String columnUserTagEvidence = 'evidence';

}
