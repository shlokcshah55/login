import '../constants.dart';

/// Model class for user data from Supabase
class UserModel {
  final int? userId;
  final String? supabaseId; // For Supabase auth integration
  final String? name;
  final String email;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  
  UserModel({
    this.userId,
    this.supabaseId,
    this.name,
    required this.email,
    this.profileImageUrl,
    this.createdAt,
    this.lastLogin,
  });

  /// Create a UserModel from a JSON map
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json[SupabaseConstants.columnUserId],
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
    );
  }

  /// Convert UserModel to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'email': email,
    };
    
    if (userId != null) data[SupabaseConstants.columnUserId] = userId;
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
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      supabaseId: supabaseId ?? this.supabaseId,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}