class MessageModel {
  final String id;
  final String bubbleId;
  final String senderId;
  final String senderName;
  final String senderAvatarUrl;
  final String content;
  final String messageType;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? repliedToMessageId;

  MessageModel({
    required this.id,
    required this.bubbleId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.content,
    required this.messageType,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
    this.repliedToMessageId,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, {String? bubbleId}) {
    return MessageModel(
      id: json['id'] ?? '',
      bubbleId: bubbleId ?? json['bubble_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderName: json['sender_name'] ?? '',
      senderAvatarUrl: json['sender_avatar_url'] ?? '',
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? 'text',
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      repliedToMessageId: json['replied_to_message_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bubble_id': bubbleId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar_url': senderAvatarUrl,
      'content': content,
      'message_type': messageType,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'replied_to_message_id': repliedToMessageId,
    };
  }

  MessageModel copyWith({
    String? id,
    String? bubbleId,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? content,
    String? messageType,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? repliedToMessageId,
  }) {
    return MessageModel(
      id: id ?? this.id,
      bubbleId: bubbleId ?? this.bubbleId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      repliedToMessageId: repliedToMessageId ?? this.repliedToMessageId,
    );
  }
}
