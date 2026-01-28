import 'package:flutter/material.dart';
import 'package:login/models/bubble.dart';

class ChatGroupTile extends StatefulWidget {
  final Bubble bubble;
  final VoidCallback onTap;

  const ChatGroupTile({
    Key? key,
    required this.bubble,
    required this.onTap,
  }) : super(key: key);

  @override
  _ChatGroupTileState createState() => _ChatGroupTileState();
}

class _ChatGroupTileState extends State<ChatGroupTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildGroupAvatar(theme),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildChatInfo(theme),
                    ),
                    _buildRightSection(theme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupAvatar(ThemeData theme) {
    return Stack(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                theme.primaryColor,
                theme.primaryColor.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: widget.bubble.groupAvatar.isNotEmpty
                ? Image.network(
                    widget.bubble.groupAvatar,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.group,
                        color: Colors.white,
                        size: 30,
                      );
                    },
                  )
                : Icon(
                    Icons.group,
                    color: Colors.white,
                    size: 30,
                  ),
          ),
        ),
        if (widget.bubble.isOnline)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.cardColor,
                  width: 3,
                ),
              ),
            ),
          ),
        if (widget.bubble.unreadCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.cardColor,
                  width: 2,
                ),
              ),
              child: Text(
                widget.bubble.unreadCount > 99 
                    ? '99+' 
                    : widget.bubble.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.bubble.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.bubble.unreadCount > 0 
                      ? theme.primaryColor 
                      : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              widget.bubble.lastMessageTime,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.bubble.lastMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: widget.bubble.unreadCount > 0 
                ? theme.textTheme.bodyMedium?.color 
                : Colors.grey[600],
            fontWeight: widget.bubble.unreadCount > 0 
                ? FontWeight.w600 
                : FontWeight.normal,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        _buildMemberAvatars(theme),
      ],
    );
  }

  Widget _buildMemberAvatars(ThemeData theme) {
    final visibleAvatars = widget.bubble.memberAvatars.take(4).toList();
    final remainingCount = widget.bubble.memberCount - visibleAvatars.length;

    return Row(
      children: [
        ...visibleAvatars.asMap().entries.map((entry) {
          final index = entry.key;
          final avatar = entry.value;
          
          return Container(
            margin: EdgeInsets.only(left: index > 0 ? 8 : 0),
            child: CircleAvatar(
              radius: 12,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              backgroundColor: theme.primaryColor.withOpacity(0.2),
              child: avatar.isEmpty
                  ? Icon(Icons.person, color: theme.primaryColor, size: 14)
                  : null,
            ),
          );
        }).toList(),
        if (remainingCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+$remainingCount',
              style: TextStyle(
                color: theme.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRightSection(ThemeData theme) {
    return Column(
      children: [
        Icon(
          Icons.location_on,
          color: widget.bubble.groupLocations.isNotEmpty 
              ? theme.primaryColor 
              : Colors.grey[400],
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          widget.bubble.groupLocations.length.toString(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: widget.bubble.groupLocations.isNotEmpty 
                ? theme.primaryColor 
                : Colors.grey[400],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}