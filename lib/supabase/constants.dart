/// Supabase table and column name constants
class SupabaseConstants {
  // Table names
  static const String tableLocations = 'locations';
  static const String tableVideos = 'videos';
  static const String tableUserFriends = 'user_friends';
  static const String tableUserLocationActions = 'user_location_actions';
  static const String tableLocationPopularityApp = 'location_popularity_app';
  static const String tableUsers = 'users';
  static const String tableBubbles = 'bubbles';
  static const String tableBubbleMembers = 'bubble_members';
  static const String tableBubbleLocations = 'bubble_locations';
  static const String tableCollections = 'collections';
  static const String tableCollectionLocations = 'collection_locations';
  static const String tableCollectionSaves = 'collection_saves';
  static const String tableTags = 'tags';
  static const String tableUserTags = 'user_tag_affinities';
  static const String tableUserTagAffinities = 'user_tag_affinities';
  static const String tableNotifications = 'notifications';
  static const String tableRecommendationRuns = 'recommendation_runs';
  static const String tableRecommendationCandidates =
      'recommendation_candidates';
  static const String tableUserRecommendations = 'user_recommendations';
  static const String tableMessages = 'messages';
  static const String tableUserChatState = 'user_chat_state';
  static const String tableLocationReviews = 'location_reviews';
  static const String tableVideoInsights = 'video_insights';
  static const String tableRewardReferrals = 'referrals';

  // Schema names
  static const String schemaRewards = 'rewards';

  // RPC names
  static const String rpcApplyReferralCode = 'apply_referral_code';
  static const String rpcAcceptPendingReferralForUser =
      'accept_pending_referral_for_user';
  static const String rpcGetMyReferralDashboard = 'get_my_referral_dashboard';
  static const String rpcRedeemVoucher = 'redeem_voucher';

  // RPC params
  static const String paramReferralCode = 'p_code';
  static const String paramUserId = 'p_user_id';
  static const String paramVoucherId = 'p_voucher_id';

  // Column names - users
  static const String columnSupabaseId = 'supabase_id';
  static const String name = 'name';
  static const String columnEmail = 'email';
  static const String columnBio = 'bio';
  static const String columnProfileImageUrl = 'profile_image_url';
  static const String columnWizardCompleted = 'wizard_completed';
  static const String columnLegalConsentAcceptedAt =
      'legal_consent_accepted_at';
  static const String columnGeneratedCollections = 'generated_collections';
  static const String columnReferralCode = 'referral_code';
  static const String columnVerified = 'verified';
  static const String columnUsername = 'username';
  static const String columnSpiceTolerance = 'spice_tolerance';
  static const String columnFcmToken = 'fcm_token';
  static const String columnFcmTokenUpdatedAt = 'fcm_token_updated_at';
  static const String columnVibeTagAffinity = 'vibe_tag_affinity';
  static const String columnDietaryRequirementTagAffinity =
      'dietary_requirement_tag_affinity';

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
  static const String columnImageUrl = 'image_url';
  static const String columnSavedCount = 'saved_count';
  static const String columnGooglePlaceId = 'google_place_id';
  static const String columnBusinessStatus = 'business_status';
  static const String columnEditorialSummary = 'editorial_summary';
  static const String columnWebsite = 'website';
  static const String columnInternationalPhoneNumber =
      'international_phone_number';
  static const String columnTypes = 'types';
  static const String columnOpeningHoursText = 'opening_hours_text';
  static const String columnOpeningHoursPeriods = 'opening_hours_periods';
  static const String columnOpenNow = 'open_now';
  static const String columnCuisineDetected = 'cuisine_detected';
  static const String columnCuisineSource = 'cuisine_source';
  static const String columnCuisinePrimary = 'cuisine_primary';
  static const String columnTopReviewLanguage = 'top_review_language';
  static const String columnTopLanguageShare = 'top_language_share';
  static const String columnReviewLanguageCountsJson =
      'review_language_counts_json';
  static const String columnIsOpenLate = 'is_open_late';
  static const String columnIsOpenEarly = 'is_open_early';
  static const String columnIsSundayOpen = 'is_sunday_open';
  static const String columnPriceBucket = 'price_bucket';
  static const String columnLogReviews = 'log_reviews';
  static const String columnDerivedAttributes = 'derived_attributes';
  static const String columnDataVersion = 'data_version';
  static const String columnIngestedAt = 'ingested_at';
  static const String columnPhotoReferenceValidUntil =
      'photo_reference_valid_until';
  static const String columnPhotoReferenceScore = 'photo_reference_score';
  static const String columnImageStored = 'image_stored';
  static const String columnImageUnavailable = 'image_unavailable';
  static const String columnExtraPhotosStored = 'extra_photos_stored';
  static const String columnEmoji = 'emoji';
  static const String columnGoogleMapsUri = 'google_maps_uri';
  static const String columnPhotos = 'photos';
  static const String columnReviews = 'reviews';
  static const String columnReviewSummary = 'review_summary';
  static const String columnGoodForChildren = 'good_for_children';
  static const String columnGoodForGroups = 'good_for_groups';
  static const String columnGoodForWatchingSports = 'good_for_watching_sports';
  static const String columnLiveMusic = 'live_music';
  static const String columnOutdoorSeating = 'outdoor_seating';
  static const String columnServesBeer = 'serves_beer';
  static const String columnServesBreakfast = 'serves_breakfast';
  static const String columnServesBrunch = 'serves_brunch';
  static const String columnServesCocktails = 'serves_cocktails';
  static const String columnServesCoffee = 'serves_coffee';
  static const String columnServesDessert = 'serves_dessert';
  static const String columnServesDinner = 'serves_dinner';
  static const String columnServesLunch = 'serves_lunch';
  static const String columnServesVegetarianFood = 'serves_vegetarian_food';
  static const String columnServesWine = 'serves_wine';
  static const String columnMenu = 'menu';
  static const String columnGeneratedSummary = 'generated_summary';
  static const String columnRecommendedDishes =
      'reccomended_dishes'; // note: DB typo preserved
  static const String columnMenuAnalysisConfidence = 'menu_analysis_confidence';
  static const String columnVibeVector = 'vibe_vector';
  static const String columnUpdatedVibe = 'updated_vibe';
  static const String columnIsTakeaway = 'is_takeaway';
  static const String columnDietaryRequirementVector =
      'dietary_requirement_vector';
  static const String columnCuisineScoresJson = 'cuisine_scores_json';
  static const String columnSocialVideoCount = 'social_video_count';
  static const String columnSocialVideoUrl = 'social_video_url';
  static const String columnSocialVideoCreatorHandle =
      'social_video_creator_handle';
  static const String columnTikTokRecommendedDish = 'tiktok_recommended_dish';

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
  static const String columnVideoExtras = 'video_extras';

  // Column names - location_popularity_app
  static const String columnSavesCount = 'saves_count';
  static const String columnDislikesCount = 'dislikes_count';
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

  // Column names - collections
  static const String columnCollectionId = 'collection_id';
  static const String columnDescription = 'description';
  static const String columnCoverColor = 'cover_color';
  static const String columnIsCurated = 'is_curated';
  static const String columnIsPublic = 'is_public';

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
  static const String columnSource = 'source';
  // columnMetadata and columnCreatedAt are already defined above

  // Column names - location_reviews
  static const String columnContentReview = 'content';
  static const String columnRatingReview = 'rating';
  static const String columnPrivate = 'private';

  // Column names - user_tags
  // columnId, columnUserId, and columnTagId are already defined above

  // Column names - user_tag_affinities
  // columnUserId, columnTagId, columnUpdatedAt are already defined above
  static const String columnUserTagAffinity = 'affinity';
  static const String columnUserTagEvidence = 'evidence';

  // Column names - notifications
  // columnUserId, columnCreatedAt are already defined above
  static const String columnNotificationId = 'id';
  static const String columnType = 'type';
  static const String columnTitle = 'title';
  static const String columnMessage = 'message';
  static const String columnMetadata = 'metadata';
  static const String columnIsRead = 'is_read';
  static const String columnReadAt = 'read_at';

  // Column names - messages
  // columnId, columnBubbleId, columnCreatedAt, columnMetadata are already defined
  static const String columnSenderId = 'sender_id';
  static const String columnContent = 'content';
  static const String columnMessageType = 'message_type';
  static const String columnIsDeleted = 'is_deleted';
  static const String columnRepliedToMessageId = 'replied_to_message_id';

  // Column names - user_chat_state
  // columnUserId, columnBubbleId are already defined
  static const String columnLastReadAt = 'last_read_at';
  static const String columnMuted = 'muted';

  // Enum values - action_type
  static const String actionSave = 'save';
  static const String actionSharedVideo = 'shared_video';
  static const String actionDislike = 'dislike';
  static const String actionBeenTo = 'been_to';

  // Enum values - saved_method
  static const String savedMethodTikTok = 'tiktok';
  static const String savedMethodInApp = 'in-app';

  // Enum values - relationship_status
  static const String relationshipStatusAccepted = 'accepted';
  static const String relationshipStatusRequested = 'requested';
  static const String relationshipStatusBlocked = 'blocked';

  // Enum values - tag_type
  static const String tagTypeDietaryRequirement = 'dietary_requirement';
  static const String tagTypeVibe = 'vibe';
  static const String tagTypeCuisine = 'cuisine';

  static const String supabaseStorageBucketProfileImages = 'profile_photos';

  static const String supabaseStorageBucketCollectionCovers =
      'collection_covers';
}
