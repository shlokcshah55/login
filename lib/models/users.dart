import 'dart:math' as math;

import '../supabase/constants.dart';

/// Model class for user data from Supabase
class UserModel {
  final String? supabaseId; // For Supabase auth integration
  final String? name;
  final String email;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final int? spiceTolerance; // 1-5 scale
  final bool wizardCompleted;
  final String? username;

  /// User's vibe-tag affinity vector (real[] on the server; indices match tag order).
  /// Stored as doubles end-to-end to avoid rounding on every client/server round-trip.
  final List<double>? vibeTagAffinity;

  /// User’s dietary-requirement affinity vector (integer[]).
  final List<int>? dietaryRequirementTagAffinity;

  /// Whether the user has already generated AI collections at least once.
  final bool generatedCollections;
  final String? referralCode;

  UserModel({
    this.supabaseId,
    this.name,
    required this.email,
    this.profileImageUrl,
    this.createdAt,
    this.lastLogin,
    this.bio = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.spiceTolerance,
    this.wizardCompleted = false,
    this.username,
    this.vibeTagAffinity,
    this.dietaryRequirementTagAffinity,
    this.generatedCollections = false,
    this.referralCode,
  });

  // ─────────────── Match-scoring helpers ───────────────

  /// Cosine similarity between the user’s vibe affinity and a location’s
  /// vibe vector (both double-lists of the same length).
  /// Returns 0.0 when either vector is absent or empty.
  double vibeMatchScore(List<double>? locationVibeVector) {
    if (vibeTagAffinity == null || locationVibeVector == null) return 0.0;
    if (vibeTagAffinity!.isEmpty || locationVibeVector.isEmpty) return 0.0;
    final len = math.min(vibeTagAffinity!.length, locationVibeVector.length);
    double dot = 0, magA = 0, magB = 0;
    for (var i = 0; i < len; i++) {
      final a = vibeTagAffinity![i];
      final b = locationVibeVector[i];
      dot += a * b;
      magA += a * a;
      magB += b * b;
    }
    if (magA == 0 || magB == 0) return 0.0;
    return dot / (math.sqrt(magA) * math.sqrt(magB));
  }

  /// Cosine similarity between the user’s dietary requirement affinity
  /// and a location’s dietary requirement vector.
  double dietaryMatchScore(List<int>? locationDietaryVector) {
    if (dietaryRequirementTagAffinity == null || locationDietaryVector == null)
      return 0.0;
    if (dietaryRequirementTagAffinity!.isEmpty || locationDietaryVector.isEmpty)
      return 0.0;
    final len = math.min(
        dietaryRequirementTagAffinity!.length, locationDietaryVector.length);
    double dot = 0, magA = 0, magB = 0;
    for (var i = 0; i < len; i++) {
      final a = dietaryRequirementTagAffinity![i].toDouble();
      final b = locationDietaryVector[i].toDouble();
      dot += a * b;
      magA += a * a;
      magB += b * b;
    }
    if (magA == 0 || magB == 0) return 0.0;
    return dot / (math.sqrt(magA) * math.sqrt(magB));
  }

  /// Cosine similarity between this user's vibe affinity and another user's
  /// vibe affinity. Returns null if either vector is missing or empty so
  /// callers can hide the indicator gracefully.
  double? vibeSimilarityWith(UserModel other) {
    final a = vibeTagAffinity;
    final b = other.vibeTagAffinity;
    if (a == null || b == null || a.isEmpty || b.isEmpty) return null;
    final len = math.min(a.length, b.length);
    double dot = 0, magA = 0, magB = 0;
    for (var i = 0; i < len; i++) {
      final x = a[i];
      final y = b[i];
      dot += x * y;
      magA += x * x;
      magB += y * y;
    }
    if (magA == 0 || magB == 0) return null;
    return dot / (math.sqrt(magA) * math.sqrt(magB));
  }

  /// Whether this user has any affinity vectors populated.
  bool get hasAffinityData =>
      (vibeTagAffinity != null && vibeTagAffinity!.isNotEmpty) ||
      (dietaryRequirementTagAffinity != null &&
          dietaryRequirementTagAffinity!.isNotEmpty);

  /// Create a UserModel from a JSON map
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      supabaseId: json[SupabaseConstants.columnSupabaseId],
      name: json[SupabaseConstants.columnName],
      email: json[SupabaseConstants.columnEmail] ?? '',
      profileImageUrl: json[SupabaseConstants.columnProfileImageUrl],
      createdAt: json[SupabaseConstants.columnCreatedAt] != null
          ? DateTime.tryParse(
              json[SupabaseConstants.columnCreatedAt].toString())
          : null,
      lastLogin: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'].toString())
          : null,
      bio: json[SupabaseConstants.columnBio] ?? '',
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      spiceTolerance:
          (json[SupabaseConstants.columnSpiceTolerance] as num?)?.toInt(),
      wizardCompleted: json[SupabaseConstants.columnWizardCompleted] ?? false,
      username: json[SupabaseConstants.columnUsername] ?? '',
      vibeTagAffinity: json[SupabaseConstants.columnVibeTagAffinity] != null
          ? <double>[
              for (final e
                  in (json[SupabaseConstants.columnVibeTagAffinity] as List))
                (e as num).toDouble(),
            ]
          : null,
      dietaryRequirementTagAffinity:
          json[SupabaseConstants.columnDietaryRequirementTagAffinity] != null
              ? List<int>.from(
                  (json[SupabaseConstants.columnDietaryRequirementTagAffinity]
                          as List)
                      .map((e) => (e as num).toInt()))
              : null,
      generatedCollections:
          json[SupabaseConstants.columnGeneratedCollections] != null,
      referralCode: json[SupabaseConstants.columnReferralCode] as String?,
    );
  }

  /// Convert UserModel to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      SupabaseConstants.columnEmail: email,
    };

    if (supabaseId != null)
      data[SupabaseConstants.columnSupabaseId] = supabaseId;
    if (name != null) data[SupabaseConstants.columnName] = name;
    if (profileImageUrl != null)
      data[SupabaseConstants.columnProfileImageUrl] = profileImageUrl;
    if (bio != null) data[SupabaseConstants.columnBio] = bio;
    if (username != null) data[SupabaseConstants.columnUsername] = username;
    if (spiceTolerance != null)
      data[SupabaseConstants.columnSpiceTolerance] = spiceTolerance;
    if (vibeTagAffinity != null)
      data[SupabaseConstants.columnVibeTagAffinity] = vibeTagAffinity;
    if (dietaryRequirementTagAffinity != null) {
      data[SupabaseConstants.columnDietaryRequirementTagAffinity] =
          dietaryRequirementTagAffinity;
    }
    if (referralCode != null)
      data[SupabaseConstants.columnReferralCode] = referralCode;

    return data;
  }

  /// Create a copy of this UserModel with updated fields
  UserModel copyWith({
    String? supabaseId,
    String? name,
    String? email,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? bio,
    int? followersCount,
    int? followingCount,
    int? spiceTolerance,
    bool? wizardCompleted,
    String? username,
    List<double>? vibeTagAffinity,
    List<int>? dietaryRequirementTagAffinity,
    bool? generatedCollections,
    String? referralCode,
  }) {
    return UserModel(
      supabaseId: supabaseId ?? this.supabaseId,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      spiceTolerance: spiceTolerance ?? this.spiceTolerance,
      wizardCompleted: wizardCompleted ?? this.wizardCompleted,
      username: username ?? this.username,
      vibeTagAffinity: vibeTagAffinity ?? this.vibeTagAffinity,
      dietaryRequirementTagAffinity:
          dietaryRequirementTagAffinity ?? this.dietaryRequirementTagAffinity,
      generatedCollections: generatedCollections ?? this.generatedCollections,
      referralCode: referralCode ?? this.referralCode,
    );
  }
}
