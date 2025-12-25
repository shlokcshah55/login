import 'package:login/models/locations.dart';

class ChatGroupModel {
  final String id;
  final String name;
  final String lastMessage;
  final String lastMessageTime;
  final int memberCount;
  final List<String> memberAvatars;
  final String groupAvatar;
  final bool isOnline;
  final int unreadCount;
  final List<LocationModel> groupLocations;
  final String description;
  final List<String> memberIds;

  ChatGroupModel({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.memberCount,
    required this.memberAvatars,
    required this.groupAvatar,
    this.isOnline = false,
    this.unreadCount = 0,
    this.groupLocations = const [],
    this.description = '',
    this.memberIds = const [],
  });

  factory ChatGroupModel.fromJson(Map<String, dynamic> json) {

    return ChatGroupModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      lastMessage: json['last_message'] ?? '',
      lastMessageTime: json['last_message_time'] ?? '',
      memberCount: json['member_count'] ?? 0,
      memberAvatars: List<String>.from(json['member_avatars'] ?? []),
      groupAvatar: json['group_avatar'] ?? '',
      isOnline: json['is_online'] ?? false,
      unreadCount: json['unread_count'] ?? 0,
      groupLocations: (json['group_locations'] as List<dynamic>?)
          ?.map((loc) => LocationModel.fromJson(loc, ""))
          .toList() ?? [],
      description: json['description'] ?? '',
      memberIds: List<String>.from(json['member_ids'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime,
      'member_count': memberCount,
      'member_avatars': memberAvatars,
      'group_avatar': groupAvatar,
      'is_online': isOnline,
      'unread_count': unreadCount,
      'group_locations': groupLocations.map((loc) => loc.toJson()).toList(),
      'description': description,
      'member_ids': memberIds,
    };
  }
}