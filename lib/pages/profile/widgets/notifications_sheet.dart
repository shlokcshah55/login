import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/notification_type.dart';
import 'package:login/models/notifications/base_notification.dart';
import 'package:login/services/fcm_service.dart';
import 'pinit_colors.dart';

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: PinitColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: StreamBuilder<BaseNotification>(
        stream: FCMService().notificationStream,
        builder: (context, snapshot) {
          final notifications = FCMService().notifications;
          final unreadCount = FCMService().unreadCount;

          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: PinitColors.aubergine.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              fontFamily: 'Rova',
                              fontSize: 28,
                              fontWeight: FontWeight.w100,
                              color: PinitColors.aubergine,
                              letterSpacing: 1.9,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            unreadCount > 0
                                ? '$unreadCount unread updates'
                                : 'You are all caught up',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: PinitColors.aubergineSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unreadCount > 0)
                      GestureDetector(
                        onTap: FCMService().markAllAsRead,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: PinitColors.cream,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: PinitColors.aubergine,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            'Mark all read',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: PinitColors.aubergine,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: notifications.isEmpty
                    ? const _EmptyNotifications()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return _NotificationItem(notification: notification);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final BaseNotification notification;

  const _NotificationItem({
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(notification.type);
    final body = notification.getNotificationBody().trim();
    final title = notification.getNotificationTitle().trim();
    final showBody = body.isNotEmpty && body != title;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: notification.isRead ? 0.84 : 1,
        child: Container(
          decoration: const BoxDecoration(
            color: PinitColors.cream,
            border: Border.fromBorderSide(
              BorderSide(color: PinitColors.aubergine, width: 1.5),
            ),
            borderRadius: BorderRadius.all(Radius.circular(10)),
            boxShadow: [
              BoxShadow(
                color: PinitColors.aubergine,
                blurRadius: 0,
                offset: Offset(4, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.5),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: meta.accentColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  meta.label,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                    color: meta.accentColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  title,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: PinitColors.aubergine,
                                    height: 1.2,
                                  ),
                                ),
                                if (showBody) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    body,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: PinitColors.aubergineSoft,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                notification.getFormattedTimestamp(),
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: PinitColors.mute,
                                ),
                              ),
                              if (!notification.isRead) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: meta.accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _NotificationMeta _metaFor(NotificationType type) {
    switch (type) {
      case NotificationType.videoProcessed:
        return const _NotificationMeta(
          label: 'VIDEO READY',
          accentColor: PinitColors.primary,
        );
      case NotificationType.followRequest:
        return const _NotificationMeta(
          label: 'FOLLOW REQUEST',
          accentColor: Color(0xFFE85D4C),
        );
      case NotificationType.followAccepted:
        return const _NotificationMeta(
          label: 'FOLLOW ACCEPTED',
          accentColor: Color(0xFF34A853),
        );
      case NotificationType.friendVisitedLocation:
        return const _NotificationMeta(
          label: 'FRIEND ACTIVITY',
          accentColor: PinitColors.primary,
        );
      case NotificationType.proximityLocation:
        return const _NotificationMeta(
          label: 'NEARBY PIN',
          accentColor: Color(0xFFFFB800),
        );
      case NotificationType.newMessage:
        return const _NotificationMeta(
          label: 'NEW MESSAGE',
          accentColor: Color(0xFF5B4DC7),
        );
      case NotificationType.userAddedToBubble:
        return const _NotificationMeta(
          label: 'BUBBLE INVITE',
          accentColor: Color(0xFF5B4DC7),
        );
    }
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: PinitColors.cream,
            border: Border.fromBorderSide(
              BorderSide(color: PinitColors.aubergine, width: 1.5),
            ),
            borderRadius: BorderRadius.all(Radius.circular(10)),
            boxShadow: [
              BoxShadow(
                color: PinitColors.aubergine,
                blurRadius: 0,
                offset: Offset(4, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: PinitColors.creamSunk,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 28,
                  color: PinitColors.aubergineSoft,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'All caught up!',
                style: TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 24,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  letterSpacing: 1.4,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No new notifications right now.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: PinitColors.aubergineSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationMeta {
  final String label;
  final Color accentColor;

  const _NotificationMeta({
    required this.label,
    required this.accentColor,
  });
}
