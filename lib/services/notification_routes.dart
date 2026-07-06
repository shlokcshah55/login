String? resolveNotificationDeepLink(Map<String, dynamic> data) {
  final existing =
      _firstNonEmptyString(data, const ['deepLink', 'deep_link', 'deeplink']);
  if (existing != null) return existing;

  final type = _normalizeType(data['type']);

  switch (type) {
    case 'follow_request':
    case 'follow_accepted':
      final userId = _firstNonEmptyString(data, const ['userId']);
      return userId == null ? null : 'pinit://user/$userId';

    case 'proximity_location':
      final locationId = _firstNonEmptyString(data, const ['locationId']);
      return locationId == null ? null : 'pinit://location/$locationId';

    case 'user_added_to_bubble':
    case 'new_message':
      final bubbleId = _firstNonEmptyString(data, const ['bubbleId']);
      return bubbleId == null ? null : 'pinit://bubble/$bubbleId';

    case 'video_processed':
      final locationId = _firstNonEmptyString(data, const ['locationId']);
      return locationId == null ? null : 'pinit://location/$locationId';

    case 'social_post_review':
      final socialPostId = _firstNonEmptyString(data, const ['socialPostId']);
      return socialPostId == null ? null : 'pinit://social-review/$socialPostId';

    default:
      return null;
  }
}

String _normalizeType(Object? raw) {
  final normalized = (raw?.toString() ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return '';
  switch (normalized) {
    case 'location_saved':
      return 'video_processed';
    case 'proximity_locaiton':
      return 'proximity_location';
    default:
      return normalized;
  }
}

String? _firstNonEmptyString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final raw = data[key];
    final value = raw?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
