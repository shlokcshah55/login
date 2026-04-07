import 'package:flutter/material.dart';
import 'package:login/models/bubble.dart';

class ChatGroupTile extends StatefulWidget {
  const ChatGroupTile({
    super.key,
    required this.bubble,
    required this.onTap,
    this.onOpenChat,
    this.onActivateBubble,
  });

  final Bubble bubble;
  final VoidCallback onTap;
  final VoidCallback? onOpenChat;
  final VoidCallback? onActivateBubble;

  @override
  State<ChatGroupTile> createState() => _ChatGroupTileState();
}

class _ChatGroupTileState extends State<ChatGroupTile> {
  static const _borderColor = Color(0xFFF5DEE6);
  static const _roseAccent = Color(0xFFD95D85);
  static const _textPrimary = Color(0xFF563440);
  static const _textSecondary = Color(0xFF8B7180);
  static const _timeText = Color(0xFFB89AAA);
  static const _pillBackground = Color(0xFFFFF3F5);
  static const _pinPillBackground = Color(0xFFFFF3E4);

  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          key: Key('bubble_tile_surface_${widget.bubble.id}'),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.bubble.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: _textPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.bubble.lastMessageTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _timeText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.bubble.lastMessage.isEmpty
                          ? 'No messages yet. Tap to peek inside.'
                          : widget.bubble.lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: widget.bubble.lastMessage.isEmpty
                            ? _timeText
                            : _textSecondary,
                        height: 1.35,
                        fontWeight: widget.bubble.unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildMemberPreview(theme)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _buildMetadataChips(theme),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildTrailingAccent(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          key: Key('bubble_tile_avatar_shell_${widget.bubble.id}'),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFD5E0),
                Color(0xFFFFEDDB),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: widget.bubble.groupAvatar.isNotEmpty
                ? Image.network(
                    widget.bubble.groupAvatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.bubble_chart_rounded,
                      size: 30,
                      color: _roseAccent,
                    ),
                  )
                : const Icon(
                    Icons.bubble_chart_rounded,
                    size: 30,
                    color: _roseAccent,
                  ),
          ),
        ),
        if (widget.bubble.isOnline)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF5BC6A9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMemberPreview(ThemeData theme) {
    final avatars = widget.bubble.memberAvatars.take(3).toList();
    final overflowCount = widget.bubble.memberCount - avatars.length;

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        if (avatars.isNotEmpty)
          SizedBox(
            width: avatars.length * 18.0 + 16,
            height: 24,
            child: Stack(
              children: [
                for (var index = 0; index < avatars.length; index++)
                  Positioned(
                    left: index * 18.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 11,
                        backgroundImage: avatars[index].isNotEmpty
                            ? NetworkImage(avatars[index])
                            : null,
                        backgroundColor: const Color(0xFFFFECF1),
                        child: avatars[index].isEmpty
                            ? const Icon(
                                Icons.person_rounded,
                                size: 12,
                                color: _roseAccent,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (avatars.isNotEmpty) const SizedBox(width: 6),
        Expanded(
          child: Text(
            overflowCount > 0
                ? '+$overflowCount more inside'
                : '${widget.bubble.memberCount} members',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataChips(ThemeData theme) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 6,
      runSpacing: 6,
      children: [
        _InfoChip(
          containerKey:
              Key('bubble_tile_metadata_chip_members_${widget.bubble.id}'),
          icon: Icons.people_outline_rounded,
          label: '${widget.bubble.memberCount}',
          color: _roseAccent,
          backgroundColor: _pillBackground,
        ),
        _InfoChip(
          containerKey:
              Key('bubble_tile_metadata_chip_locations_${widget.bubble.id}'),
          icon: Icons.location_on_outlined,
          label: '${widget.bubble.groupLocations.length}',
          color: const Color(0xFFCA8A2D),
          backgroundColor: _pinPillBackground,
        ),
      ],
    );
  }

  Widget _buildTrailingAccent(ThemeData theme) {
    if (widget.bubble.unreadCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0E2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          widget.bubble.unreadCount > 99
              ? '99+'
              : widget.bubble.unreadCount.toString(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: const Color(0xFFB77B2C),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: Icon(
        Icons.chevron_right_rounded,
        color: _timeText,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    this.containerKey,
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final Key? containerKey;
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: containerKey,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
