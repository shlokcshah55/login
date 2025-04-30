import '../constants.dart';

/// Model class for user location actions data from Supabase
class UserLocationActionModel {
  final int? actionId;
  final int userId;
  final int locationId;
  final String action; // 'save', 'like', 'shared_video'
  final int? sourceVideoId;
  final DateTime? createdAt;
  final String? savedMethod; // 'tiktok', 'in-app'
  
  UserLocationActionModel({
    this.actionId,
    required this.userId,
    required this.locationId,
    required this.action,
    this.sourceVideoId,
    this.createdAt,
    this.savedMethod,
  });

  /// Create a UserLocationActionModel from a JSON map
  factory UserLocationActionModel.fromJson(Map<String, dynamic> json) {
    return UserLocationActionModel(
      actionId: json[SupabaseConstants.columnActionId],
      userId: json[SupabaseConstants.columnUserId],
      locationId: json[SupabaseConstants.columnLocationId],
      action: json[SupabaseConstants.columnAction],
      sourceVideoId: json[SupabaseConstants.columnSourceVideoId],
      createdAt: json[SupabaseConstants.columnCreatedAt] != null 
          ? DateTime.parse(json[SupabaseConstants.columnCreatedAt])
          : null,
      savedMethod: json[SupabaseConstants.columnSavedMethod],
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
    if (sourceVideoId != null) data[SupabaseConstants.columnSourceVideoId] = sourceVideoId;
    if (savedMethod != null) data[SupabaseConstants.columnSavedMethod] = savedMethod;
    
    return data;
  }

  /// Create a copy of this UserLocationActionModel with updated fields
  UserLocationActionModel copyWith({
    int? actionId,
    int? userId,
    int? locationId,
    String? action,
    int? sourceVideoId,
    DateTime? createdAt,
    String? savedMethod,
  }) {
    return UserLocationActionModel(
      actionId: actionId ?? this.actionId,
      userId: userId ?? this.userId,
      locationId: locationId ?? this.locationId,
      action: action ?? this.action,
      sourceVideoId: sourceVideoId ?? this.sourceVideoId,
      createdAt: createdAt ?? this.createdAt,
      savedMethod: savedMethod ?? this.savedMethod,
    );
  }
}