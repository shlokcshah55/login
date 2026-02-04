import 'package:flutter/material.dart';
import 'package:login/models/bubble.dart';

class ChatGroupTile extends StatefulWidget {
  final Bubble bubble;
  final VoidCallback onTap;
  final VoidCallback? onOpenChat;
  final VoidCallback? onActivateBubble;

  const ChatGroupTile({
    Key? key,
    required this.bubble,
    required this.onTap,
    this.onOpenChat,
    this.onActivateBubble,
  }) : super(key: key);

  @override
  _ChatGroupTileState createState() => _ChatGroupTileState();
}

class _ChatGroupTileState extends State<ChatGroupTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
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
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Main content area
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _buildGroupAvatar(theme),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildChatInfo(theme),
                        ),
                      ],
                    ),
                  ),
                  // Stats row
                  _buildStatsRow(theme),
                  // Action buttons
                  _buildActionButtons(theme),
                ],
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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
                color: theme.primaryColor.withOpacity(0.25),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: widget.bubble.groupAvatar.isNotEmpty
                ? Image.network(
                    widget.bubble.groupAvatar,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.bubble_chart_rounded,
                        color: Colors.white,
                        size: 28,
                      );
                    },
                  )
                : const Icon(
                    Icons.bubble_chart_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
          ),
        ),
        if (widget.bubble.isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.cardColor,
                  width: 2.5,
                ),
              ),
            ),
          ),
        if (widget.bubble.unreadCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252),
                borderRadius: BorderRadius.circular(10),
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
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.bubble.lastMessageTime,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.bubble.lastMessage.isNotEmpty
              ? widget.bubble.lastMessage
              : 'No messages yet',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: widget.bubble.lastMessage.isNotEmpty
                ? Colors.grey[600]
                : Colors.grey[400],
            fontWeight: widget.bubble.unreadCount > 0
                ? FontWeight.w500
                : FontWeight.normal,
            fontStyle: widget.bubble.lastMessage.isEmpty
                ? FontStyle.italic
                : FontStyle.normal,
          ),
          maxLines: 1,
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

    return SizedBox(
      height: 24,
      child: Row(
        children: [
          // Stacked avatars
          SizedBox(
            width: visibleAvatars.length * 16.0 + 8,
            child: Stack(
              children: [
                ...visibleAvatars.asMap().entries.map((entry) {
                  final index = entry.key;
                  final avatar = entry.value;

                  return Positioned(
                    left: index * 16.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.cardColor, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundImage:
                            avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        backgroundColor: theme.primaryColor.withOpacity(0.2),
                        child: avatar.isEmpty
                            ? Icon(Icons.person,
                                color: theme.primaryColor, size: 10)
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (remainingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+$remainingCount more',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildStatItem(
            theme,
            Icons.people_outline_rounded,
            '${widget.bubble.memberCount}',
            'members',
          ),
          const SizedBox(width: 20),
          _buildStatItem(
            theme,
            Icons.location_on_outlined,
            '${widget.bubble.groupLocations.length}',
            'pins',
          ),
          if (widget.bubble.unreadCount > 0) ...[
            const SizedBox(width: 20),
            _buildStatItem(
              theme,
              Icons.mark_chat_unread_outlined,
              '${widget.bubble.unreadCount}',
              'unread',
              color: const Color(0xFFFF5252),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(
      ThemeData theme, IconData icon, String value, String label,
      {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color ?? Colors.grey[700],
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Open Chat Button
          Expanded(
            child: _ActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Open Chat',
              onTap: widget.onOpenChat ?? widget.onTap,
              isPrimary: false,
              theme: theme,
            ),
          ),
          const SizedBox(width: 10),
          // Activate Bubble Button
          Expanded(
            child: _ActionButton(
              icon: Icons.bubble_chart_rounded,
              label: 'Activate',
              onTap: widget.onActivateBubble ?? () {},
              isPrimary: true,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final ThemeData theme;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
    required this.theme,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: widget.isPrimary
              ? LinearGradient(
                  colors: [
                    widget.theme.primaryColor,
                    widget.theme.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: widget.isPrimary ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          boxShadow: widget.isPrimary && !_isPressed
              ? [
                  BoxShadow(
                    color: widget.theme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        transform: _isPressed
            ? Matrix4.translationValues(0, 1, 0)
            : Matrix4.identity(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 18,
              color: widget.isPrimary ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.isPrimary ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
