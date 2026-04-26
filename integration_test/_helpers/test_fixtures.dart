// ignore_for_file: lines_longer_than_80_chars
//
// Shared test fixtures for the PinIt integration_test suite.
//
// Keep these factories thin — they create valid domain objects with
// sensible defaults so each test can override just the fields under test.

import 'package:login/models/bubble.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/proximal_models.dart';
import 'package:login/models/users.dart';

/// Fabricate a [LocationModel] for tests.
///
/// `locationId` is the only field most tests care about (shortlist de-duping,
/// contains() checks, etc.) — the rest has reasonable defaults.
LocationModel buildLocation({
  int locationId = 1,
  String name = 'Test Venue',
  String? vicinity = '123 Test Street',
  double? rating = 4.5,
  String? cuisinePrimary,
}) {
  return LocationModel(
    locationId: locationId,
    name: name,
    vicinity: vicinity,
    rating: rating,
    cuisinePrimary: cuisinePrimary,
    createdAt: DateTime.utc(2025, 1, 1),
  );
}

/// Fabricate a [UserModel]. `email` uniquely identifies users in tests.
///
/// A sentinel is used for [supabaseId] so callers can explicitly pass `null`
/// (handy for widget tests that want UserCard's follow-lookup to early-return)
/// while the common case still gets a derived, stable id.
const _unsetSupabaseId = Object();
UserModel buildUser({
  Object? supabaseId = _unsetSupabaseId,
  String? username,
  String? name = 'Test User',
  String email = 'test@example.com',
  String? bio,
  String? profileImageUrl,
  int followersCount = 0,
  int followingCount = 0,
  bool wizardCompleted = false,
  List<double>? vibeTagAffinity,
}) {
  final resolvedId = identical(supabaseId, _unsetSupabaseId)
      ? 'user-${email.hashCode}'
      : supabaseId as String?;
  return UserModel(
    supabaseId: resolvedId,
    name: name,
    email: email,
    bio: bio ?? '',
    profileImageUrl: profileImageUrl,
    username: username,
    followersCount: followersCount,
    followingCount: followingCount,
    wizardCompleted: wizardCompleted,
    vibeTagAffinity: vibeTagAffinity,
  );
}

/// Fabricate a [Bubble] for bubble-search/messaging tests.
Bubble buildBubble({
  String id = 'bubble-1',
  String name = 'Friday Foodies',
  String description = 'Weekend eats',
  String lastMessage = 'See you there!',
  String lastMessageTime = '2025-04-20T18:00:00Z',
  int memberCount = 3,
  int unreadCount = 0,
  List<String> memberIds = const ['u1', 'u2', 'u3'],
}) {
  return Bubble(
    id: id,
    name: name,
    description: description,
    lastMessage: lastMessage,
    lastMessageTime: lastMessageTime,
    memberCount: memberCount,
    memberAvatars: const [],
    groupAvatar: '',
    unreadCount: unreadCount,
    memberIds: memberIds,
  );
}

/// A canonical fake JSON payload that the recommendations backend would return.
///
/// Covers top-level fields, two recommendations, and one [TasteBreakdown]
/// so parsing tests exercise every branch of [ProximalResponse.fromJson].
Map<String, dynamic> fakeProximalResponseJson({
  String userId = 'user-1',
  int resultCount = 2,
}) {
  final recommendations = List<Map<String, dynamic>>.generate(
    resultCount,
    (i) => {
      'location_id': 100 + i,
      'name': 'Recommended Spot ${i + 1}',
      'vicinity': '${i + 1} Elm Street',
      'cuisine_primary': i.isEven ? 'italian' : 'thai',
      'rating': 4.0 + (i * 0.2),
      'user_ratings_total': 100 + i * 10,
      'price_level': (i % 3) + 1,
      'distance_km': 0.5 + (i * 0.3),
      'taste_score': 0.8 - (i * 0.1),
      'proximity_score': 0.9 - (i * 0.05),
      'quality_score': 0.75,
      'final_score': 0.85 - (i * 0.05),
      'rank': i + 1,
      'taste_breakdown': [
        {
          'tag': 'cozy',
          'user_score': 0.7,
          'location_score': 0.8,
          'contribution': 0.24,
        },
      ],
    },
  );

  return {
    'user_id': userId,
    'center_lat': 51.5074,
    'center_lon': -0.1278,
    'radius_km': 2.0,
    'total_results': resultCount,
    'recommendations': recommendations,
    'timestamp': '2025-04-20T12:00:00Z',
  };
}
