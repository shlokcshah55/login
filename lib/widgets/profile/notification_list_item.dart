import 'package:flutter/material.dart';
import 'package:login/models/notification.dart';

class NotificationListItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onActionTap;

  const NotificationListItem({
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
            // Mini Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(notification.userAvatar),
                backgroundColor: Colors.grey[200],
              ),
            ),
            const SizedBox(width: 12),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Username and message
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(
                          text: notification.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: ' ${notification.message}',
                          style: const TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
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
            if (notification.actionLabel != null) ...[
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onActionTap ?? () {
                  // Show toast message for now
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${notification.actionLabel} action pressed'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
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
                  notification.actionLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
