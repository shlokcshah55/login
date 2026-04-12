import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/notification_type.dart';
import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notifications/follow_request_notification.dart';
import 'package:login/models/notifications/video_processed_notification.dart';
import 'package:login/pages/profile/other_user_profile_page.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/supabase/service.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:provider/provider.dart';

class NotificationsPopover extends StatefulWidget {
  const NotificationsPopover({Key? key}) : super(key: key);

  @override
  State<NotificationsPopover> createState() => _NotificationsPopoverState();
}

class _NotificationsPopoverState extends State<NotificationsPopover> {
  late List<BaseNotification> _notifications;
  late StreamSubscription<BaseNotification> _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notifications = FCMService().notifications;

    _notificationSubscription =
        FCMService().notificationStream.listen((notification) {
      if (!mounted) return;
      setState(() {
        _notifications = FCMService().notifications;
      });
    });
  }

  Future<void> _handleRefresh() async {
    await FCMService().refreshFromDB();

    if (!mounted) return;
    setState(() {
      _notifications = FCMService().notifications;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: PinitColors.aubergine,
        content: Text(
          'Notifications refreshed',
          style: GoogleFonts.dmSans(color: PinitColors.cream),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    await FCMService().markAllAsRead();

    if (!mounted) return;
    setState(() {
      _notifications = FCMService().notifications;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: PinitColors.aubergine,
        content: Text(
          'All notifications marked as read',
          style: GoogleFonts.dmSans(color: PinitColors.cream),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _handleNotificationTap(BaseNotification notification) async {
    if (notification.isRead) return;

    await FCMService().markAsRead(notification.id);

    if (!mounted) return;
    setState(() {
      _notifications = FCMService().notifications;
    });
  }

  Future<void> _handleAction(BaseNotification notification) async {
    if (notification is FollowRequestNotification) {
      await _handleFollowRequestAccept(notification);
    } else if (notification is VideoProcessedNotification) {
      await _handleViewLocation(notification);
    }
  }

  Future<void> _handleFollowRequestAccept(
      FollowRequestNotification notification) async {
    try {
      final auth = Provider.of<SupabaseService>(context, listen: false).users;
      await auth.acceptFollowRequest(notification.userId);
      await FCMService().markAsRead(notification.id);
      await FCMService().refreshFromDB();
      if (!mounted) return;
      setState(() => _notifications = FCMService().notifications);

      // Navigate to requester's profile
      final user = await auth.getUserProfileById(notification.userId);
      if (!mounted || user == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtherUserProfilePage(user: user),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept request: $e')),
      );
    }
  }

  Future<void> _handleViewLocation(
      VideoProcessedNotification notification) async {
    try {
      await FCMService().markAsRead(notification.id);
      if (!mounted) return;
      setState(() => _notifications = FCMService().notifications);

      final service = Provider.of<SupabaseService>(context, listen: false);
      final locationId = int.tryParse(notification.locationId);
      if (locationId == null) return;

      final locations = await service.locations.getLocationsByIds([locationId]);
      if (!mounted || locations.isEmpty) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            body: ExpandedLocationCard(
              location: locations.first,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open location: $e')),
      );
    }
  }

  @override
  void dispose() {
    _notificationSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = FCMService().unreadCount;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: PinitColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: PinitColors.cream,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: PinitColors.aubergine,
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: PinitColors.aubergine,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontFamily: 'Rova',
                            fontSize: 30,
                            fontWeight: FontWeight.w100,
                            color: PinitColors.aubergine,
                            letterSpacing: 1.9,
                            height: 1.02,
                          ),
                        ),
                        const SizedBox(height: 5),
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
                      onTap: _markAllAsRead,
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
              child: _notifications.isEmpty
                  ? const _EmptyNotifications()
                  : RefreshIndicator(
                      onRefresh: _handleRefresh,
                      color: PinitColors.aubergine,
                      backgroundColor: PinitColors.cream,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding:
                            EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return _NotificationCard(
                            notification: notification,
                            onTap: () => _handleNotificationTap(notification),
                            onActionTap: notification.hasAction() &&
                                    notification.getActionLabel() != null
                                ? () => _handleAction(notification)
                                : null,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final BaseNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onActionTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(notification.type);
    final title = notification.getNotificationTitle().trim();
    final body = notification.getNotificationBody().trim();
    final showBody = body.isNotEmpty && body != title;
    final actionLabel = notification.getActionLabel();

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: onTap,
      child: Container(
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
                                  if (actionLabel != null &&
                                      onActionTap != null) ...[
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        // Stop the card-level onTap from also firing
                                        onActionTap!();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: PinitColors.aubergine,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          actionLabel.toUpperCase(),
                                          style: GoogleFonts.dmSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                            color: PinitColors.cream,
                                          ),
                                        ),
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
      case NotificationType.notesImportComplete:
        return const _NotificationMeta(
          label: 'IMPORT COMPLETE',
          accentColor: Color(0xFF34A853),
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
