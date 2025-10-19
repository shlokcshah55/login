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
  });

  /// Create a UserModel from a JSON map
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      supabaseId: json['supabase_id'], // Assuming you have this field
      name: json['name'],
      email: json['email'],
      profileImageUrl: json['profile_image_url'],
      createdAt: json[SupabaseConstants.columnCreatedAt] != null
          ? DateTime.parse(json[SupabaseConstants.columnCreatedAt])
          : null,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
      bio: json['bio'] ?? '',
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
    );
  }

  /// Convert UserModel to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'email': email,
      'followers_count': followersCount,
      'following_count': followingCount,
    };

    if (supabaseId != null) data['supabase_id'] = supabaseId;
    if (name != null) data['name'] = name;
    if (profileImageUrl != null) data['profile_image_url'] = profileImageUrl;

    return data;
  }

  /// Create a copy of this UserModel with updated fields
  UserModel copyWith({
    int? userId,
    String? supabaseId,
    String? name,
    String? email,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? lastLogin,
    int? followersCount,
    int? followingCount,
  }) {
    return UserModel(
      supabaseId: supabaseId ?? this.supabaseId,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }
}
