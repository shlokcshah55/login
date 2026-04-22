import 'package:login/models/locations.dart';

class Bubble {
  final String id;
  final String name;
  final String lastMessage;
  final String lastMessageTime;
  final DateTime? lastActivityAt;
  final int memberCount;
  final List<String> memberAvatars;
  final String groupAvatar;
  final bool isOnline;
  final int unreadCount;
  final List<LocationModel> groupLocations;
  final String description;
  final List<String> memberIds;
  final List<String> memberNames;
  final int? compatibilityScore;

  Bubble({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    this.lastActivityAt,
    required this.memberCount,
    required this.memberAvatars,
    required this.groupAvatar,
    this.isOnline = false,
    this.unreadCount = 0,
    this.groupLocations = const [],
    this.description = '',
    this.memberIds = const [],
    this.memberNames = const [],
    this.compatibilityScore,
  });

  factory Bubble.fromJson(Map<String, dynamic> json) {
    return Bubble(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      lastMessage: json['last_message'] ?? '',
      lastMessageTime: json['last_message_time'] ?? '',
      lastActivityAt: json['last_activity_at'] != null
          ? DateTime.parse(json['last_activity_at'])
          : null,
      memberCount: json['member_count'] ?? 0,
      memberAvatars: List<String>.from(json['member_avatars'] ?? []),
      groupAvatar: json['group_avatar'] ?? '',
      isOnline: json['is_online'] ?? false,
      unreadCount: json['unread_count'] ?? 0,
      groupLocations: (json['group_locations'] as List<dynamic>?)
              ?.map((loc) => LocationModel.fromJson(loc, ''))
              .toList() ??
          [],
      description: json['description'] ?? '',
      memberIds: List<String>.from(json['member_ids'] ?? []),
      memberNames: List<String>.from(json['member_names'] ?? []),
      compatibilityScore: json['compatibility_score'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime,
      'last_activity_at': lastActivityAt?.toIso8601String(),
      'member_count': memberCount,
      'member_avatars': memberAvatars,
      'group_avatar': groupAvatar,
      'is_online': isOnline,
      'unread_count': unreadCount,
      'group_locations': groupLocations.map((loc) => loc.toJson()).toList(),
      'description': description,
      'member_ids': memberIds,
      'member_names': memberNames,
      if (compatibilityScore != null) 'compatibility_score': compatibilityScore,
    };
  }

  Bubble copyWith({
    String? id,
    String? name,
    String? lastMessage,
    String? lastMessageTime,
    DateTime? lastActivityAt,
    int? memberCount,
    List<String>? memberAvatars,
    String? groupAvatar,
    bool? isOnline,
    int? unreadCount,
    List<LocationModel>? groupLocations,
    String? description,
    List<String>? memberIds,
    List<String>? memberNames,
    int? compatibilityScore,
  }) {
    return Bubble(
      id: id ?? this.id,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      memberCount: memberCount ?? this.memberCount,
      memberAvatars: memberAvatars ?? this.memberAvatars,
      groupAvatar: groupAvatar ?? this.groupAvatar,
      isOnline: isOnline ?? this.isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
      groupLocations: groupLocations ?? this.groupLocations,
      description: description ?? this.description,
      memberIds: memberIds ?? this.memberIds,
      memberNames: memberNames ?? this.memberNames,
      compatibilityScore: compatibilityScore ?? this.compatibilityScore,
    );
  }
}
