import 'package:flutter/material.dart';

import '../../models/message.dart';
import 'message_bubble.dart';

class MessageList extends StatelessWidget {
  final List<MessageModel> messages;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final bool hasMore;
  final String? currentUserId;
  final VoidCallback? onLoadMore;

  const MessageList({
    Key? key,
    required this.messages,
    required this.scrollController,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.currentUserId,
    this.onLoadMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _buildEmptyState(context);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          // Load more when scrolled to top (since list is reversed)
          if (scrollController.position.pixels >=
                  scrollController.position.maxScrollExtent - 200 &&
              hasMore &&
              !isLoadingMore) {
            onLoadMore?.call();
          }
        }
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: messages.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (isLoadingMore && index == messages.length) {
            return _buildLoadingIndicator();
          }

          final message = messages[index];
          final isFromCurrentUser = message.senderId == currentUserId;

          // Check if we should show sender info (for group chat)
          // Show if it's the last message from this sender in a row
          bool showSenderInfo = true;
          if (index < messages.length - 1) {
            final nextMessage = messages[index + 1];
            showSenderInfo = nextMessage.senderId != message.senderId;
          }

          return MessageBubble(
            message: message,
            isFromCurrentUser: isFromCurrentUser,
            showSenderInfo: showSenderInfo && !isFromCurrentUser,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
