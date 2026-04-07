import 'package:flutter/material.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/actions.dart';
import 'package:login/pages/bubble_messaging_page.dart';
import 'package:login/supabase/service.dart';
import 'package:login/providers/bubble_mode_provider.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/widgets/chat/add_members_dialog.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

class ExpandedChatView extends StatefulWidget {
  final Bubble bubble;
  final VoidCallback onClose;

  const ExpandedChatView({
    Key? key,
    required this.bubble,
    required this.onClose,
  }) : super(key: key);

  @override
  _ExpandedChatViewState createState() => _ExpandedChatViewState();
}

class _ExpandedChatViewState extends State<ExpandedChatView>
    with TickerProviderStateMixin {
  static const _sheetBackground = Color(0xFFFFFBF8);
  static const _sheetBorder = Color(0xFFF4DDE4);
  static const _roseAccent = Color(0xFFD95D85);
  static const _softRose = Color(0xFFFFEFF3);
  static const _softAmber = Color(0xFFFFF3E2);
  static const _titleColor = Color(0xFF563440);
  static const _bodyColor = Color(0xFF8B7180);

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _messageCount = 0;
  bool _isLoadingMessageCount = true;
  bool _showMembersList = false;
  List<UserLocationActionModel> _activities = [];
  bool _isLoadingActivities = true;

  // Local state for bubble data that can be updated
  late Bubble currentBubble;

  @override
  void initState() {
    super.initState();
    currentBubble = widget.bubble;
    _initializeAnimations();
    _loadMessageCount();
    _loadBubbleActivity();
  }

  Future<void> _loadMessageCount() async {
    try {
      final count =
          await SupabaseService().messaging.getUnreadCount(widget.bubble.id);
      if (mounted) {
        setState(() {
          _messageCount = count;
          _isLoadingMessageCount = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMessageCount = false;
        });
      }
    }
  }

  Future<void> _loadBubbleActivity() async {
    try {
      final activities =
          await SupabaseService().bubbles.getBubbleActivity(widget.bubble.id);

      if (mounted) {
        setState(() {
          _activities = activities;
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingActivities = false;
        });
      }
    }
  }

  Future<void> _reloadBubbleData() async {
    try {
      final updatedBubble =
          await SupabaseService().bubbles.getBubbleById(widget.bubble.id);

      if (updatedBubble != null && mounted) {
        setState(() {
          currentBubble = updatedBubble;
        });
      }
    } catch (e) {
      print('Error reloading bubble data: $e');
    }
  }

  void _showAddMembersDialog() {
    showDialog(
      context: context,
      builder: (context) => AddMembersDialog(
        bubble: currentBubble,
        onMembersAdded: () async {
          // Reload the bubble data after members are added
          await _reloadBubbleData();
        },
      ),
    );
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0x52000000),
      body: GestureDetector(
        onTap: _handleClose,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    width: screenSize.width * 0.9,
                    height: screenSize.height * 0.8,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFDFB),
                          _sheetBackground,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: _sheetBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x29000000),
                          blurRadius: 34,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildHeader(Theme.of(context)),
                        _buildGroupInfo(Theme.of(context)),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildTopRecommendationsPodium(
                                    Theme.of(context)),
                                const SizedBox(height: 16),
                                _buildGroupChatCard(Theme.of(context)),
                                const SizedBox(height: 16),
                                _buildRecentActivity(Theme.of(context)),
                                const SizedBox(height: 16),
                                _buildStatsRow(Theme.of(context)),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          child: _showMembersList
                              ? _buildMembersList(Theme.of(context))
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE3E9),
            Color(0xFFFFF0DD),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: currentBubble.groupAvatar.isNotEmpty
                ? NetworkImage(currentBubble.groupAvatar)
                : null,
            backgroundColor: Colors.white,
            child: currentBubble.groupAvatar.isEmpty
                ? const Icon(Icons.group, color: _roseAccent)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentBubble.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _titleColor,
                  ),
                ),
                Text(
                  '${currentBubble.memberCount} members • ${currentBubble.groupLocations.length} locations',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _bodyColor,
                  ),
                ),
              ],
            ),
          ),
          _buildHeaderIconButton(
            icon: Icons.person_add,
            onPressed: _showAddMembersDialog,
            tooltip: 'Add Members',
          ),
          _buildHeaderIconButton(
            icon: Icons.open_in_full,
            onPressed: _navigateToBubbleProfile,
            tooltip: 'Expand to full view',
          ),
          _buildHeaderIconButton(
            icon: Icons.close,
            onPressed: _handleClose,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInfo(ThemeData theme) {
    if (currentBubble.description.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _sheetBorder),
      ),
      child: Text(
        currentBubble.description,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: _bodyColor,
          height: 1.35,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _showMembersList = !_showMembersList;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: _buildStatCard(
                theme,
                _showMembersList ? Icons.people : Icons.people_outline,
                currentBubble.memberCount.toString(),
                'MEMBERS',
                theme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              theme,
              Icons.location_on_outlined,
              currentBubble.groupLocations.length.toString(),
              'SHARED',
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              theme,
              Icons.favorite_border,
              '0',
              'SAVED',
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      ThemeData theme, IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _sheetBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _bodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChatCard(ThemeData theme) {
    return GestureDetector(
      onTap: _navigateToGroupChat,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFEEF3),
              Color(0xFFFFFBF4),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _sheetBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: _roseAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group Chat',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _isLoadingMessageCount
                      ? Text(
                          'Loading...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _bodyColor,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : _messageCount > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _roseAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_messageCount unread messages',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : Text(
                              'No unread messages',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _bodyColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                ],
              ),
            ),
            _buildMemberAvatarsPreview(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAvatarsPreview(ThemeData theme) {
    final avatars = currentBubble.memberAvatars.take(3).toList();
    final remaining = currentBubble.memberAvatars.length - 3;

    return SizedBox(
      width: 70,
      height: 32,
      child: Stack(
        children: [
          ...List.generate(
            avatars.length,
            (index) => Positioned(
              left: index * 18.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.cardColor, width: 2),
                ),
                child: CircleAvatar(
                  radius: 14,
                  backgroundImage: avatars[index].isNotEmpty
                      ? NetworkImage(avatars[index])
                      : null,
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.2),
                  child: avatars[index].isEmpty
                      ? Icon(Icons.person, color: theme.primaryColor, size: 14)
                      : null,
                ),
              ),
            ),
          ),
          if (remaining > 0)
            Positioned(
              left: avatars.length * 18.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.cardColor, width: 2),
                ),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    '+$remaining',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToGroupChat() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BubbleMessagingPage(
          bubble: widget.bubble,
        ),
      ),
    );
  }

  Widget _buildRecentActivity(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _sheetBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('\u26A1', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoadingActivities
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _activities.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No recent activity',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _bodyColor,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        ..._activities.take(2).map((activity) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildActivityItemFromData(theme, activity),
                          );
                        }).toList(),
                        if (_activities.length > 2)
                          Center(
                            child: TextButton(
                              onPressed: _navigateToBubbleProfile,
                              child: Text('View All'),
                            ),
                          ),
                      ],
                    ),
        ],
      ),
    );
  }

  Widget _buildActivityItemFromData(
      ThemeData theme, UserLocationActionModel activity) {
    // Determine icon and action text based on action type
    IconData icon;
    String actionText;

    switch (activity.action) {
      case 'save':
        icon = Icons.favorite_border;
        actionText = 'saved';
        break;
      case 'shared_video':
        icon = Icons.video_library_outlined;
        actionText = 'shared a video about';
        break;
      default:
        icon = Icons.star_outline;
        actionText = 'performed an action on';
    }

    // Get time ago text
    final timeAgo =
        activity.createdAt != null ? _getTimeAgo(activity.createdAt!) : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _softRose,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _sheetBorder),
      ),
      child: Row(
        children: [
          // User profile photo
          CircleAvatar(
            radius: 20,
            backgroundImage: activity.user_avatar_url != null &&
                    activity.user_avatar_url!.isNotEmpty
                ? NetworkImage(activity.user_avatar_url!)
                : null,
            backgroundColor: Colors.white,
            child: activity.user_avatar_url == null ||
                    activity.user_avatar_url!.isEmpty
                ? const Icon(Icons.person, color: _roseAccent, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          // User name, action, and location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // User name
                    Text(
                      activity.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Action text
                    Expanded(
                      child: Text(
                        actionText,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Location name with icon
                Row(
                  children: [
                    Icon(icon, size: 14, color: theme.primaryColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        activity.locationName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _roseAccent,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (timeAgo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    timeAgo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _bodyColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // See more button
          TextButton(
            onPressed: () {
              // TODO: Add functionality
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'See more',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _roseAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  Widget _buildTopRecommendationsPodium(ThemeData theme) {
    // Get random top 3 locations (for now, until we implement actual ranking)
    final random = math.Random();
    final locations = currentBubble.groupLocations.toList();
    locations.shuffle(random);
    final top3 = locations.take(3).toList();

    if (top3.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _sheetBorder),
        ),
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No recommendations yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _bodyColor,
              ),
            ),
            Text(
              'Start adding pins to see top picks!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _bodyColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFEEF3),
            Color(0xFFFFF7E8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _sheetBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: _roseAccent, size: 28),
              const SizedBox(width: 8),
              Text(
                'Top Recommendations',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd place
              if (top3.length > 1)
                _buildPodiumPlace(theme, top3[1], 2, 80, Colors.grey[400]!),
              // 1st place
              if (top3.isNotEmpty)
                _buildPodiumPlace(theme, top3[0], 1, 100, Colors.amber),
              // 3rd place
              if (top3.length > 2)
                _buildPodiumPlace(theme, top3[2], 3, 60, Colors.brown[300]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace(ThemeData theme, dynamic location, int place,
      double height, Color medalColor) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: medalColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.2),
            border: Border.all(color: medalColor, width: 2),
          ),
          child: Center(
            child: Text(
              '$place',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: medalColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: medalColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, color: medalColor, size: 24),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  location.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget _buildActivityItem(ThemeData theme, IconData icon, String title, String description, String time) {
  //   return Row(
  //     children: [
  //       Container(
  //         width: 40,
  //         height: 40,
  //         decoration: BoxDecoration(
  //           color: theme.primaryColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.1),
  //           shape: BoxShape.circle,
  //         ),
  //         child: Icon(icon, color: theme.primaryColor, size: 20),
  //       ),
  //       const SizedBox(width: 12),
  //       Expanded(
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               title,
  //               style: theme.textTheme.bodyMedium?.copyWith(
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             const SizedBox(height: 2),
  //             Text(
  //               description,
  //               style: theme.textTheme.bodySmall?.copyWith(
  //                 color: Colors.grey[600],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       Text(
  //         time,
  //         style: theme.textTheme.bodySmall?.copyWith(
  //           color: Colors.grey[500],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  void _navigateToBubbleProfile() {
    print('Navigating to bubble profile for bubble: ${currentBubble.name}');
    final bubbleModeProvider = context.read<BubbleModeProvider>();
    final navigationProvider = context.read<NavigationProvider>();

    bubbleModeProvider.requestBubbleMode(currentBubble);
    navigationProvider.navigateToTab(0);

    Navigator.of(context).pop();
  }

  Widget _buildMembersList(ThemeData theme) {
    // Generate member names (for now using placeholder names)
    final memberNames = [
      'Sarah Chen',
      'Mike Johnson',
      'Emma Davis',
      'Alex Kim',
      'Lisa Brown',
      'Tom Wilson',
      'Maya Patel',
      'Chris Lee',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        border: Border(top: BorderSide(color: _sheetBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Group Members',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...List.generate(
                currentBubble.memberAvatars.length,
                (index) {
                  final name = index < memberNames.length
                      ? memberNames[index]
                      : 'Member ${index + 1}';

                  return Container(
                    decoration: BoxDecoration(
                      color: _softRose,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _sheetBorder),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: currentBubble
                                  .memberAvatars[index].isNotEmpty
                              ? NetworkImage(currentBubble.memberAvatars[index])
                              : null,
                          backgroundColor: Colors.white,
                          child: currentBubble.memberAvatars[index].isEmpty
                              ? const Icon(Icons.person,
                                  color: _roseAccent, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Add Members button
              GestureDetector(
                onTap: _showAddMembersDialog,
                child: Container(
                  decoration: BoxDecoration(
                    color: _softAmber,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _sheetBorder,
                      width: 1.5,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_add,
                        color: _roseAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add Members',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _roseAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
      widget.onClose();
    });
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: _roseAccent),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}
