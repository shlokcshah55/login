import 'package:flutter/material.dart';
import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notification_type.dart';
import 'package:login/models/notifications/video_processed_notification.dart';
import 'package:login/models/notifications/follow_request_notification.dart';
import 'package:login/models/notifications/follow_accepted_notification.dart';
import 'package:login/models/notifications/friend_visited_location_notification.dart';
import 'package:login/models/notifications/friend_added_bubble_notification.dart';

class SmartNotificationListItem extends StatelessWidget {
  final BaseNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onActionTap;

  const SmartNotificationListItem({
    Key? key,
    required this.notification,
    this.onTap,
    this.onActionTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.grey[100] : Colors.white,
          border: Border(
            left: BorderSide(
              color: notification.isRead
                  ? Colors.transparent
                  : theme.primaryColor,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar - different for video processed vs user notifications
            _buildAvatar(),
            const SizedBox(width: 12),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message with rich text formatting
                  _buildMessage(theme),
                  const SizedBox(height: 4),

                  // Timestamp
                  Text(
                    notification.getFormattedTimestamp(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Optional Action Button
            if (notification.hasAction() && notification.getActionLabel() != null) ...[
              const SizedBox(width: 12),
              _buildActionButton(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    // Use app logo for video processed notifications
    if (notification.type == NotificationType.videoProcessed) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: CircleAvatar(
          radius: 20,
          backgroundImage: const AssetImage('lib/assets/default_avatar.png'),
          backgroundColor: Colors.grey[200],
        ),
      );
    }

    // Use user avatar for all other notifications
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(notification.getAvatarUrl()),
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildMessage(ThemeData theme) {
    // Format message based on type
    switch (notification.type) {
      case NotificationType.videoProcessed:
        final videoNotif = notification as VideoProcessedNotification;
        return RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
              height: 1.3,
            ),
            children: [
              const TextSpan(
                text: 'We have saved ',
              ),
              TextSpan(
                text: videoNotif.locationName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: ' from the shared TikTok',
              ),
            ],
          ),
        );

      case NotificationType.followRequest:
        final followReqNotif = notification as FollowRequestNotification;
        return RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
              height: 1.3,
            ),
            children: [
              TextSpan(
                text: followReqNotif.username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: ' has requested to follow you',
              ),
            ],
          ),
        );

      case NotificationType.followAccepted:
        final followAccNotif = notification as FollowAcceptedNotification;
        return RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
              height: 1.3,
            ),
            children: [
              TextSpan(
                text: followAccNotif.username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: ' has accepted your follow request',
              ),
            ],
          ),
        );

      case NotificationType.friendVisitedLocation:
        final locationNotif = notification as FriendVisitedLocationNotification;
        return RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
              height: 1.3,
            ),
            children: [
              TextSpan(
                text: locationNotif.username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: ' went to ',
              ),
              TextSpan(
                text: locationNotif.locationName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      case NotificationType.friendAddedToBubble:
        final bubbleNotif = notification as FriendAddedToBubbleNotification;
        return RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
              height: 1.3,
            ),
            children: [
              TextSpan(
                text: bubbleNotif.username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: ' saved a location to ',
              ),
              TextSpan(
                text: bubbleNotif.bubbleName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildActionButton(ThemeData theme) {
    // Different button colors based on action type
    Color buttonColor;
    if (notification.type == NotificationType.followRequest) {
      buttonColor = Colors.blue; // Accent color for accept button
    } else {
      buttonColor = theme.primaryColor; // Primary color for view button
    }

    return ElevatedButton(
      onPressed: onActionTap ?? () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
      ),
      child: Text(
        notification.getActionLabel()!,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
