import '../supabase/constants.dart';

/// Model class for user location actions data from Supabase
class UserLocationActionModel {
  final int? actionId;
  final String userId;
  final int locationId;
  final String action; // 'save', 'shared_video'
  final String? sourceVideoId;
  final DateTime? createdAt;
  final String? savedMethod; // 'tiktok', 'in-app'
  final String name;
  final String? user_avatar_url;
  final String locationName;

  UserLocationActionModel({
    this.actionId,
    required this.userId,
    required this.locationId,
    required this.action,
    this.sourceVideoId,
    this.createdAt,
    this.savedMethod,
    required this.name,
    this.user_avatar_url,
    required this.locationName,
  });

  /// Create a UserLocationActionModel from a JSON map
  factory UserLocationActionModel.fromJson(Map<String, dynamic> json) {
    print(json);
    print(json['location_name']);
    return UserLocationActionModel(
      actionId: json[SupabaseConstants.columnActionId],
      userId: json[SupabaseConstants.columnUserId],
      locationId: json[SupabaseConstants.columnLocationId],
      action: json[SupabaseConstants.columnAction],
      sourceVideoId: json[SupabaseConstants.columnSourceVideoUrl],
      createdAt: json[SupabaseConstants.columnCreatedAt] != null
          ? DateTime.parse(json[SupabaseConstants.columnCreatedAt])
          : null,
      savedMethod: json[SupabaseConstants.columnSavedMethod],
      name: json['user_name'],
      user_avatar_url: json[SupabaseConstants.columnProfileImageUrl] ,
      locationName: json['location_name'],

    );
  }

  /// Convert UserLocationActionModel to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      SupabaseConstants.columnUserId: userId,
      SupabaseConstants.columnLocationId: locationId,
      SupabaseConstants.columnAction: action,
    };

    if (actionId != null) data[SupabaseConstants.columnActionId] = actionId;
    if (sourceVideoId != null)
      data[SupabaseConstants.columnSourceVideoUrl] = sourceVideoId;
    if (savedMethod != null)
      data[SupabaseConstants.columnSavedMethod] = savedMethod;

    return data;
  }

  /// Create a copy of this UserLocationActionModel with updated fields
  UserLocationActionModel copyWith({
    int? actionId,
    String? userId,
    int? locationId,
    String? action,
    String? sourceVideoId,
    DateTime? createdAt,
    String? savedMethod,
    String? name,
    String? user_avatar_url,
    String? locationName,
  }) {
    return UserLocationActionModel(
      actionId: actionId ?? this.actionId,
      userId: userId ?? this.userId,
      locationId: locationId ?? this.locationId,
      action: action ?? this.action,
      sourceVideoId: sourceVideoId ?? this.sourceVideoId,
      createdAt: createdAt ?? this.createdAt,
      savedMethod: savedMethod ?? this.savedMethod,
      name: name ?? this.name,
      user_avatar_url: user_avatar_url ?? this.user_avatar_url,
      locationName: locationName ?? this.locationName,
    );
  }
}
