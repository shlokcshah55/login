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
  final ValueChanged<MessageModel>? onMessageDoubleTap;
  final ValueChanged<MessageModel>? onMessageAvatarTap;
  final VoidCallback? onScrollStart;

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
    this.onMessageDoubleTap,
    this.onMessageAvatarTap,
    this.onScrollStart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          onScrollStart?.call();
        }

        if (notification is ScrollUpdateNotification &&
            notification.dragDetails != null) {
          onScrollStart?.call();
        }

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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
          final showDateSeparator = index == messages.length - 1 ||
              !_isSameLocalDay(
                message.createdAt,
                messages[index + 1].createdAt,
              );

          var showSenderInfo = true;
          if (index < messages.length - 1) {
            final nextMessage = messages[index + 1];
            showSenderInfo = nextMessage.senderId != message.senderId;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDateSeparator)
                _DateSeparator(label: _formatDateSeparator(message.createdAt)),
              MessageBubble(
                message: message,
                isFromCurrentUser: isFromCurrentUser,
                showSenderInfo: showSenderInfo && !isFromCurrentUser,
                onLocationTap: onLocationTap,
                onAvatarTap: onMessageAvatarTap,
                onDoubleTap: isFromCurrentUser ? null : onMessageDoubleTap,
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isSameLocalDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  String _formatDateSeparator(DateTime dateTime) {
    final localDate = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(localDate.year, localDate.month, localDate.day);
    final dayDelta = today.difference(messageDay).inDays;

    if (dayDelta == 0) return 'Today';
    if (dayDelta == 1) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final base = '${months[localDate.month - 1]} ${localDate.day}';
    return localDate.year == now.year ? base : '$base, ${localDate.year}';
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

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: PinitColors.creamDeep,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: PinitColors.cream.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: PinitColors.creamDeep, width: 1.2),
            ),
            child: Text(
              label,
              style: AppTypography.sans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: PinitColors.aubergineSoft,
              ),
            ),
          ),
          const Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: PinitColors.creamDeep,
            ),
          ),
        ],
      ),
    );
  }
}
