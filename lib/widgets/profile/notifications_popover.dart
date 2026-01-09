import 'dart:async';
import 'package:flutter/material.dart';
import 'package:login/models/notifications/base_notification.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/widgets/profile/notifications/smart_notification_list_item.dart';

class NotificationsPopover extends StatefulWidget {
  const NotificationsPopover({Key? key}) : super(key: key);

  @override
  _NotificationsPopoverState createState() => _NotificationsPopoverState();
}

class _NotificationsPopoverState extends State<NotificationsPopover> {
  late List<BaseNotification> _notifications;
  late StreamSubscription<BaseNotification> _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notifications = FCMService().notifications;

    // Listen for new notifications
    _notificationSubscription = FCMService().notificationStream.listen((notification) {
      setState(() {
        _notifications = FCMService().notifications;
      });
    });
  }

  Future<void> _handleRefresh() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications refreshed'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _markAllAsRead() {
    setState(() {
      // For now, just filter to keep only read notifications
      // In a real app, you would update the backend
      _notifications = _notifications.map((notif) {
        // Since notifications are immutable, we would recreate them
        // For simplicity in the UI demo, we'll just mark them as "processed"
        return notif; // In real implementation, recreate with isRead: true
      }).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _notificationSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreadCount = FCMService().unreadCount;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Custom AppBar
          Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withOpacity(0.8),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: MediaQuery.of(context).padding.top + 12,
                  bottom: 12,
                ),
                child: Row(
                  children: [
                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),

                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (unreadCount > 0)
                            Text(
                              '$unreadCount unread',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Mark all as read button
                    if (unreadCount > 0)
                      TextButton(
                        onPressed: _markAllAsRead,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Divider
            Container(
              height: 1,
              color: Colors.grey[300],
            ),

            // Notifications List
            Expanded(
              child: SafeArea(
                top: false,
                child: _notifications.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                      onRefresh: _handleRefresh,
                      color: theme.primaryColor,
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemCount: _notifications.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey[300],
                        ),
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return SmartNotificationListItem(
                            notification: notification,
                            onTap: () {
                              // Mark as read when tapped
                              // In a real app, you would update the backend
                              if (!notification.isRead) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Notification marked as read'),
                                    duration: Duration(milliseconds: 500),
                                  ),
                                );
                              }
                            },
                            onActionTap: () {
                              final actionLabel = notification.getActionLabel();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$actionLabel action pressed',
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you get notifications, they\'ll show up here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
