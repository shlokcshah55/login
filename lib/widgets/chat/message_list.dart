import 'package:flutter/material.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

import '../../models/message.dart';
import 'message_bubble.dart';

class MessageList extends StatelessWidget {
  final List<MessageModel> messages;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final bool hasMore;
  final String? currentUserId;
  final VoidCallback? onLoadMore;
  final String emptyTitle;
  final String emptySubtitle;
  final ValueChanged<MessageModel>? onLocationTap;

  const MessageList({
    Key? key,
    required this.messages,
    required this.scrollController,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.currentUserId,
    this.onLoadMore,
    this.emptyTitle = 'No messages yet',
    this.emptySubtitle =
        'Break the silence and drop the first plan, pin, or opinion.',
    this.onLocationTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
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
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 20),
        itemCount: messages.length + (isLoadingMore ? 2 : 1),
        itemBuilder: (context, index) {
          if (index == messages.length + (isLoadingMore ? 1 : 0)) {
            return const SizedBox(height: 16);
          }

          if (isLoadingMore && index == messages.length) {
            return _buildLoadingIndicator();
          }

          final message = messages[index];
          final isFromCurrentUser = message.senderId == currentUserId;

          var showSenderInfo = true;
          if (index < messages.length - 1) {
            final nextMessage = messages[index + 1];
            showSenderInfo = nextMessage.senderId != message.senderId;
          }

          return MessageBubble(
            message: message,
            isFromCurrentUser: isFromCurrentUser,
            showSenderInfo: showSenderInfo && !isFromCurrentUser,
            onLocationTap: onLocationTap,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: PinitColors.cream,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: PinitColors.creamDeep,
            width: 1.5,
          ),
          boxShadow: PinitColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: PinitColors.creamSunk,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: PinitColors.aubergine,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: AppTypography.brand(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: PinitColors.aubergine,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: AppTypography.sans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PinitColors.aubergineSoft,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(PinitColors.aubergine),
          ),
        ),
      ),
    );
  }
}
