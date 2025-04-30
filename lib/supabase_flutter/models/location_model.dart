import '../constants.dart';

/// Model class for location data from Supabase
class LocationModel {
  final int? locationId;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;
  final DateTime? createdAt;
  final String? phoneNumber;
  
  // Popularity metrics (optional, might be loaded separately)
  final int? savesCount;
  final int? likesCount;
  final int? mentionCount;

  LocationModel({
    this.locationId,
    required this.name,
    this.address,
    this.lat,
    this.lng,
    this.createdAt,
    this.phoneNumber,
    this.savesCount,
    this.likesCount,
    this.mentionCount,
  });

  /// Create a LocationModel from a JSON map
  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      locationId: json[SupabaseConstants.columnLocationId],
      name: json[SupabaseConstants.columnName],
      address: json[SupabaseConstants.columnAddress],
      lat: json[SupabaseConstants.columnLat] != null 
          ? double.parse(json[SupabaseConstants.columnLat].toString())
          : null,
      lng: json[SupabaseConstants.columnLng] != null 
          ? double.parse(json[SupabaseConstants.columnLng].toString())
          : null,
      createdAt: json[SupabaseConstants.columnCreatedAt] != null 
          ? DateTime.parse(json[SupabaseConstants.columnCreatedAt])
          : null,
      phoneNumber: json[SupabaseConstants.columnPhoneNumber],
      savesCount: json[SupabaseConstants.columnSavesCount],
      likesCount: json[SupabaseConstants.columnLikesCount],
      mentionCount: json[SupabaseConstants.columnMentionCount],
    );
  }

  /// Convert LocationModel to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      SupabaseConstants.columnName: name,
    };
    
    if (locationId != null) data[SupabaseConstants.columnLocationId] = locationId;
    if (address != null) data[SupabaseConstants.columnAddress] = address;
    if (lat != null) data[SupabaseConstants.columnLat] = lat;
    if (lng != null) data[SupabaseConstants.columnLng] = lng;
    if (phoneNumber != null) data[SupabaseConstants.columnPhoneNumber] = phoneNumber;
    
    return data;
  }

  /// Create a copy of this LocationModel with updated fields
  LocationModel copyWith({
    int? locationId,
    String? name,
    String? address,
    double? lat,
    double? lng,
    DateTime? createdAt,
    String? phoneNumber,
    int? savesCount,
    int? likesCount,
    int? mentionCount,
  }) {
    return LocationModel(
      locationId: locationId ?? this.locationId,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      savesCount: savesCount ?? this.savesCount,
      likesCount: likesCount ?? this.likesCount,
      mentionCount: mentionCount ?? this.mentionCount,
    );
  }
}