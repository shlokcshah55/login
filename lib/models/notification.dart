class NotificationModel {
  final String id;
  final String userAvatar;
  final String username;
  final String message;
  final String? actionLabel;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.userAvatar,
    required this.username,
    required this.message,
    this.actionLabel,
    required this.timestamp,
    required this.isRead,
  });

  /// Get formatted timestamp (e.g., "5 minutes ago", "2 hours ago", "3 days ago")
  String getFormattedTimestamp() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    }
  }

  /// Generate mock notifications for UI testing
  static List<NotificationModel> getMockNotifications() {
    return [
      NotificationModel(
        id: '1',
        userAvatar: 'https://i.pravatar.cc/150?img=1',
        username: 'sarah_jones',
        message: 'started following you',
        actionLabel: 'Follow',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
      ),
      NotificationModel(
        id: '2',
        userAvatar: 'https://i.pravatar.cc/150?img=2',
        username: 'mike_wilson',
        message: 'liked your pin at The Coffee House',
        actionLabel: 'View',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      NotificationModel(
        id: '3',
        userAvatar: 'https://i.pravatar.cc/150?img=3',
        username: 'emma_davis',
        message: 'commented on your pin',
        actionLabel: 'Reply',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      NotificationModel(
        id: '4',
        userAvatar: 'https://i.pravatar.cc/150?img=4',
        username: 'alex_chen',
        message: 'shared your pin',
        actionLabel: null,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
      NotificationModel(
        id: '5',
        userAvatar: 'https://i.pravatar.cc/150?img=5',
        username: 'jessica_lee',
        message: 'mentioned you in a comment',
        actionLabel: 'View',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true,
      ),
      NotificationModel(
        id: '6',
        userAvatar: 'https://i.pravatar.cc/150?img=6',
        username: 'david_park',
        message: 'liked your pin at Central Park',
        actionLabel: 'View',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        isRead: true,
      ),
      NotificationModel(
        id: '7',
        userAvatar: 'https://i.pravatar.cc/150?img=7',
        username: 'sophia_martinez',
        message: 'started following you',
        actionLabel: 'Follow',
        timestamp: DateTime.now().subtract(const Duration(days: 5)),
        isRead: true,
      ),
      NotificationModel(
        id: '8',
        userAvatar: 'https://i.pravatar.cc/150?img=8',
        username: 'james_taylor',
        message: 'commented on your pin at Beach Club',
        actionLabel: 'Reply',
        timestamp: DateTime.now().subtract(const Duration(days: 7)),
        isRead: true,
      ),
    ];
  }
}
