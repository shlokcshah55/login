import 'package:flutter/material.dart';
import 'package:login/models/chat_group_model.dart';
import 'package:login/pages/bubble_profile_page.dart';
import 'dart:math' as math;

class ExpandedChatView extends StatefulWidget {
  final ChatGroupModel chatGroup;
  final VoidCallback onClose;

  const ExpandedChatView({
    Key? key,
    required this.chatGroup,
    required this.onClose,
  }) : super(key: key);

  @override
  _ExpandedChatViewState createState() => _ExpandedChatViewState();
}

class _ExpandedChatViewState extends State<ExpandedChatView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 0.5),
      body: GestureDetector(
        onTap: _handleClose,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping on the card
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
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildHeader(theme),
                          _buildGroupInfo(theme),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildTopRecommendationsPodium(theme),
                                  const SizedBox(height: 16),
                                  _buildGroupActivity(theme),
                                  const SizedBox(height: 16),
                                  _buildStatisticsStickers(theme),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                          _buildMembersList(theme),
                        ],
                      ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(widget.chatGroup.groupAvatar),
            backgroundColor: theme.primaryColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.2),
            child: widget.chatGroup.groupAvatar.isEmpty
                ? Icon(Icons.group, color: theme.primaryColor)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatGroup.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.chatGroup.memberCount} members • ${widget.chatGroup.groupLocations.length} locations',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _navigateToBubbleProfile,
            icon: Icon(Icons.open_in_full, color: theme.primaryColor),
            style: IconButton.styleFrom(
              backgroundColor: theme.primaryColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.1),
            ),
            tooltip: 'Expand to full view',
          ),
          IconButton(
            onPressed: _handleClose,
            icon: Icon(Icons.close, color: theme.primaryColor),
            style: IconButton.styleFrom(
              backgroundColor: theme.primaryColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInfo(ThemeData theme) {
    if (widget.chatGroup.description.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Text(
        widget.chatGroup.description,
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTopRecommendationsPodium(ThemeData theme) {
    // Get random top 3 locations (for now, until we implement actual ranking)
    final random = math.Random();
    final locations = widget.chatGroup.groupLocations.toList();
    locations.shuffle(random);
    final top3 = locations.take(3).toList();

    if (top3.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.emoji_events, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No recommendations yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            Text(
              'Start adding pins to see top picks!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.1),
            theme.primaryColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: theme.primaryColor, size: 28),
              const SizedBox(width: 8),
              Text(
                'Top Recommendations',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
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

  Widget _buildPodiumPlace(ThemeData theme, dynamic location, int place, double height, Color medalColor) {
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

  Widget _buildGroupActivity(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 0.05),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, color: theme.primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'Group Activity',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            theme,
            Icons.add_location,
            'New pin added',
            'Sarah saved "Cozy Coffee Shop"',
            '2 hours ago',
          ),
          const Divider(height: 24),
          _buildActivityItem(
            theme,
            Icons.favorite,
            'Pin Saved',
            'Mike saved "Best Pizza Place"',
            '5 hours ago',
          ),
          const Divider(height: 24),
          _buildActivityItem(
            theme,
            Icons.comment,
            'New comment',
            'Emma: "We should go here!"',
            '1 day ago',
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _navigateToBubbleProfile,
              child: Text('View All Activity'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(ThemeData theme, IconData icon, String title, String description, String time) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsStickers(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Icon(Icons.stars, color: theme.primaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Group Stats',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatSticker(
                theme,
                '🔥',
                'Most Active',
                'Sarah',
                Colors.orange,
              ),
              _buildStatSticker(
                theme,
                '📍',
                'Most Saves',
                'Mike',
                Colors.blue,
              ),
              _buildStatSticker(
                theme,
                '⭐',
                'Top Reviewer',
                'Emma',
                Colors.amber,
              ),
              _buildStatSticker(
                theme,
                '🎯',
                'Explorer',
                'Alex',
                Colors.green,
              ),
              _buildStatSticker(
                theme,
                '💬',
                'Chattiest',
                'Lisa',
                Colors.purple,
              ),
              _buildStatSticker(
                theme,
                '🏆',
                'Trendsetter',
                'Tom',
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatSticker(ThemeData theme, String emoji, String title, String userName, Color color) {
    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(red: 0, green: 0, blue: 0, alpha: 0.2),
            color.withValues(red: 0, green: 0, blue: 0, alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(red: 0, green: 0, blue: 0, alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            userName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _navigateToBubbleProfile() {
    // Close the current dialog
    Navigator.of(context).pop();
    
    // Navigate to bubble profile page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BubbleProfilePage(
          chatGroup: widget.chatGroup,
        ),
      ),
    );
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
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              widget.chatGroup.memberAvatars.length,
              (index) {
                final name = index < memberNames.length 
                    ? memberNames[index] 
                    : 'Member ${index + 1}';
                
                return Container(
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.primaryColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: widget.chatGroup.memberAvatars[index].isNotEmpty
                            ? NetworkImage(widget.chatGroup.memberAvatars[index])
                            : null,
                        backgroundColor: theme.primaryColor.withValues(red: 0, green: 0, blue: 0, alpha: 0.3),
                        child: widget.chatGroup.memberAvatars[index].isEmpty
                            ? Icon(Icons.person, color: theme.primaryColor, size: 14)
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
}