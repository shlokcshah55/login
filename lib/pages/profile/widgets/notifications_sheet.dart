import 'package:flutter/material.dart';
import 'package:login/models/notification_type.dart';
import 'package:login/models/notifications/processing_error_notification.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/themes/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'pinit_colors.dart';

/// Notifications bottom sheet - cleaner, more modern than popover
class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notifications = FCMService().notifications;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: PinitColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: PinitColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                if (FCMService().unreadCount > 0)
                  TextButton(
                    onPressed: () {
                      FCMService().markAllAsRead();
                    },
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PinitColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Notifications list
          Expanded(
            child: notifications.isEmpty
                ? _EmptyNotifications()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _NotificationItem(
                        title: notification.getNotificationTitle(),
                        body: notification.getNotificationBody(),
                        isRead: notification.isRead,
                        timeAgo: notification.getFormattedTimestamp(),
                        type: _getNotificationType(notification),
                        actionLabel: notification is ProcessingErrorNotification
                            ? notification.getActionLabel()
                            : null,
                        onActionTap: notification is ProcessingErrorNotification &&
                                notification.hasAction()
                            ? () => _openSourceUrl(context, notification.sourceUrl!)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getNotificationType(dynamic notification) {
    if (notification.type == NotificationType.processingError) return 'error';
    final title = notification.getNotificationTitle().toLowerCase();
    if (title.contains('follow')) return 'follow';
    if (title.contains('save') || title.contains('pin')) return 'save';
    if (title.contains('collection')) return 'collection';
    return 'general';
  }

  Future<void> _openSourceUrl(BuildContext context, String sourceUrl) async {
    final parsed = Uri.tryParse(sourceUrl);
    if (parsed == null) return;

    final launched = await launchUrl(parsed, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      await AppFeedback.showError(
        context,
        title: 'Couldn’t open link',
        message: 'Please try again in a moment.',
      );
    }
  }
}

class _NotificationItem extends StatelessWidget {
  final String title;
  final String body;
  final bool isRead;
  final String timeAgo;
  final String type;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _NotificationItem({
    required this.title,
    required this.body,
    required this.isRead,
    required this.timeAgo,
    required this.type,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead
            ? Colors.white
            : PinitColors.accentSoft.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? PinitColors.surfaceLight
              : PinitColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getIconBackground(),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                _getIcon(),
                size: 20,
                color: _getIconColor(),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isRead ? FontWeight.w500 : FontWeight.w700,
                          color: PinitColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PinitColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 14,
                      color: PinitColors.textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (actionLabel != null && onActionTap != null) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onActionTap,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .tertiary
                          .withValues(alpha: 0.12),
                      foregroundColor: Theme.of(context).colorScheme.tertiary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Unread indicator
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 8, top: 6),
              decoration: const BoxDecoration(
                color: PinitColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (type) {
      case 'follow':
        return Icons.person_add_outlined;
      case 'save':
        return Icons.push_pin_outlined;
      case 'collection':
        return Icons.folder_outlined;
      case 'error':
        return Icons.link_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getIconBackground() {
    switch (type) {
      case 'follow':
        return const Color(0xFFE8F5E9);
      case 'save':
        return PinitColors.accentSoft;
      case 'collection':
        return const Color(0xFFFFF3E0);
      case 'error':
        return AppColors.info.withValues(alpha: 0.14);
      default:
        return PinitColors.surfaceLight;
    }
  }

  Color _getIconColor() {
    switch (type) {
      case 'follow':
        return PinitColors.success;
      case 'save':
        return PinitColors.primary;
      case 'collection':
        return const Color(0xFFE65100);
      case 'error':
        return AppColors.info;
      default:
        return PinitColors.textSecondary;
    }
  }
}

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: PinitColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(
                  Icons.notifications_outlined,
                  size: 36,
                  color: PinitColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'All caught up!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PinitColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No new notifications',
              style: TextStyle(
                fontSize: 15,
                color: PinitColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
