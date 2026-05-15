import 'package:login/models/locations.dart';

/// Picks the best available social-video URL for bootstrapping expanded-card
/// TikTok insights without requiring the caller to know which location fields
/// are populated in a given entry point.
String? preferredExpandedCardSocialVideoUrl(LocationModel location) {
  final savedFrom = location.savedFrom?.trim();
  if (savedFrom != null && savedFrom.isNotEmpty) {
    return savedFrom;
  }

  final socialVideoUrl = location.socialVideoUrl?.trim();
  if (socialVideoUrl != null && socialVideoUrl.isNotEmpty) {
    return socialVideoUrl;
  }

  return null;
}

/// Whether the expanded card should lazily resolve a source URL from storage
/// when it already knows this place has social-video context but no usable URL
/// is present on the location model provided by the current entry point.
bool shouldResolveExpandedCardSocialVideoUrl(
  LocationModel location, {
  required bool forceResolveOnOpen,
}) {
  if (forceResolveOnOpen) return true;
  if (preferredExpandedCardSocialVideoUrl(location) != null) return false;
  return location.hasSocialVideos;
}
