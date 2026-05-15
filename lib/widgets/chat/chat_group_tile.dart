import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/bubble.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

class ChatGroupTile extends StatefulWidget {
  final Bubble bubble;
  final VoidCallback onTap;
  final VoidCallback? onOpenChat;
  final VoidCallback? onActivateBubble;
  final Future<bool> Function()? onDelete;
  final Future<bool> Function()? onRename;

  const ChatGroupTile({
    Key? key,
    required this.bubble,
    required this.onTap,
    this.onOpenChat,
    this.onActivateBubble,
    this.onDelete,
    this.onRename,
  }) : super(key: key);

  static const List<Color> _avatarColors = [
    Color(0xFFB39DDB),
    Color(0xFF80CBC4),
    Color(0xFFFFCC80),
    Color(0xFFF48FB1),
    Color(0xFF90CAF9),
    Color(0xFFA5D6A7),
  ];

  @override
  State<ChatGroupTile> createState() => _ChatGroupTileState();
}

class _ChatGroupTileState extends State<ChatGroupTile> {
  static const Color _unreadAccent = PinitColors.aubergineSoft;
  static const Color _unreadAccentPressed = PinitColors.aubergine;
  static const Color _unreadSurface = Color(0xFFF3EDF6);
  static const Color _unreadStrip = Color(0xFFE9DDF0);
  static const Color _unreadShadow = Color(0xFF8C6D91);

  bool _showDelete = false;
  bool _isDeleting = false;
  bool _isRenaming = false;

  String _membersSubtitle() {
    if (widget.bubble.memberNames.isEmpty) {
      return '${widget.bubble.memberCount} member${widget.bubble.memberCount == 1 ? '' : 's'}';
    }
    const maxShown = 2;
    final shown = widget.bubble.memberNames.take(maxShown).join(', ');
    final extra = widget.bubble.memberNames.length - maxShown;
    return extra > 0 ? '$shown +$extra' : shown;
  }

  void _toggleDelete() {
    if ((widget.onDelete == null && widget.onRename == null) ||
        _isDeleting ||
        _isRenaming) {
      return;
    }
    setState(() => _showDelete = !_showDelete);
  }

  void _dismissDelete() {
    if (!_showDelete) return;
    setState(() => _showDelete = false);
  }

  void _handlePrimaryTap() {
    if (_showDelete) {
      _dismissDelete();
      return;
    }
    widget.onTap();
  }

  void _handleOpenChatTap() {
    if (_showDelete) {
      _dismissDelete();
      return;
    }
    (widget.onOpenChat ?? widget.onTap)();
  }

  void _handleActivateTap() {
    if (_showDelete) {
      _dismissDelete();
      return;
    }
    (widget.onActivateBubble ?? () {})();
  }

  Future<void> _handleDeleteTap() async {
    if (widget.onDelete == null || _isDeleting) return;

    setState(() => _isDeleting = true);
    try {
      final removed = await widget.onDelete!();
      if (mounted && removed) setState(() => _showDelete = false);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _handleRenameTap() async {
    if (widget.onRename == null || _isRenaming) return;

    setState(() => _isRenaming = true);
    try {
      final renamed = await widget.onRename!();
      if (mounted && renamed) setState(() => _showDelete = false);
    } finally {
      if (mounted) setState(() => _isRenaming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubble = widget.bubble;
    final isUnread = bubble.unreadCount > 0;

    return GestureDetector(
      onLongPress: (widget.onDelete != null || widget.onRename != null)
          ? _toggleDelete
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isUnread ? _unreadSurface : PinitColors.cream,
          border: Border.fromBorderSide(
            BorderSide(
              color: isUnread ? _unreadAccent : PinitColors.aubergine,
              width: 1.5,
            ),
          ),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          boxShadow: [
            BoxShadow(
              color: isUnread ? _unreadShadow : PinitColors.aubergine,
              blurRadius: 0,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Last message strip + Body ──
              GestureDetector(
                onTap: _handlePrimaryTap,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (bubble.lastMessageTime.isNotEmpty)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        color: isUnread ? _unreadStrip : PinitColors.creamSunk,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isUnread
                                  ? Icons.mark_chat_unread_rounded
                                  : Icons.access_time_rounded,
                              size: 11,
                              color:
                                  isUnread ? _unreadAccent : PinitColors.mute,
                            ),
                            const SizedBox(width: 5),
                            if (bubble.lastMessage.isNotEmpty &&
                                bubble.lastMessage !=
                                    'Tap to view locations') ...[
                              Expanded(
                                child: Text(
                                  bubble.lastMessage,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: isUnread
                                        ? PinitColors.aubergine
                                        : PinitColors.mute,
                                    fontWeight: isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ] else
                              const Spacer(),
                            Text(
                              bubble.lastMessageTime,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: isUnread
                                    ? _unreadAccentPressed
                                    : PinitColors.mute,
                                fontWeight: isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _AvatarStack(
                            avatars: bubble.memberAvatars,
                            names: bubble.memberNames,
                            colors: ChatGroupTile._avatarColors,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        bubble.name,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: PinitColors.aubergine,
                                          height: 1.15,
                                          letterSpacing: -0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      const SizedBox(width: 8),
                                      _UnreadBadge(count: bubble.unreadCount),
                                    ],
                                    if (bubble.compatibilityScore != null) ...[
                                      const SizedBox(width: 8),
                                      _ScoreBadge(
                                        score: bubble.compatibilityScore!,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _membersSubtitle(),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: isUnread
                                        ? PinitColors.aubergineSoft
                                        : PinitColors.mute,
                                    fontWeight: isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ChatButton(
                            isUnread: isUnread,
                            onTap: _handleOpenChatTap,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Activate / Delete action ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _showDelete
                    ? _EditActionsRow(
                        key: const ValueKey('delete'),
                        showRename: widget.onRename != null,
                        showDelete: widget.onDelete != null,
                        isRenaming: _isRenaming,
                        isDeleting: _isDeleting,
                        onRename: _handleRenameTap,
                        onDelete: _handleDeleteTap,
                      )
                    : _ActivateButton(
                        key: const ValueKey('activate'),
                        onTap: _handleActivateTap,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _ChatGroupTileState._unreadAccent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F6B3866),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '$count new',
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AvatarStack extends StatelessWidget {
  final List<String> avatars;
  final List<String> names;
  final List<Color> colors;

  const _AvatarStack({
    required this.avatars,
    required this.names,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final items = avatars.take(4).toList();
    if (items.isEmpty) return const SizedBox(width: 40, height: 40);

    const double size = 40.0;
    const double overlap = 14.0;
    final double stackWidth = size + (items.length - 1) * (size - overlap);

    return SizedBox(
      width: stackWidth,
      height: size,
      child: Stack(
        children: List.generate(items.length, (i) {
          final url = items[i];
          final initial = i < names.length && names[i].isNotEmpty
              ? names[i][0].toUpperCase()
              : null;
          return Positioned(
            left: i * (size - overlap),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: PinitColors.cream, width: 2),
                color: colors[i % colors.length],
              ),
              child: ClipOval(
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _Initial(initial: initial),
                      )
                    : _Initial(initial: initial),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  final String? initial;
  const _Initial({this.initial});

  @override
  Widget build(BuildContext context) {
    if (initial != null) {
      return Center(
        child: Text(
          initial!,
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }
    return const Icon(Icons.person, size: 18, color: Colors.white);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = PinitColors.matchIndicator(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        '$score%',
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChatButton extends StatefulWidget {
  final bool isUnread;
  final VoidCallback onTap;
  const _ChatButton({required this.isUnread, required this.onTap});

  @override
  State<_ChatButton> createState() => _ChatButtonState();
}

class _ChatButtonState extends State<_ChatButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: widget.isUnread
              ? (_pressed
                  ? _ChatGroupTileState._unreadAccentPressed
                  : _ChatGroupTileState._unreadAccent)
              : (_pressed ? PinitColors.creamDeep : PinitColors.creamSunk),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isUnread
                ? _ChatGroupTileState._unreadAccentPressed
                : PinitColors.creamDeep,
            width: 1,
          ),
          boxShadow: widget.isUnread
              ? const [
                  BoxShadow(
                    color: Color(0x296B3866),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          widget.isUnread
              ? Icons.chat_bubble_rounded
              : Icons.chat_bubble_outline_rounded,
          size: 18,
          color: widget.isUnread ? Colors.white : PinitColors.aubergine,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ActivateButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ActivateButton({super.key, required this.onTap});

  @override
  State<_ActivateButton> createState() => _ActivateButtonState();
}

class _ActivateButtonState extends State<_ActivateButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressed ? PinitColors.aubergineSoft : PinitColors.aubergine,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Activate',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PinitColors.cream,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _DeleteButton({
    required this.onTap,
    required this.isLoading,
  });

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _EditActionsRow extends StatelessWidget {
  final bool showRename;
  final bool showDelete;
  final bool isRenaming;
  final bool isDeleting;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _EditActionsRow({
    super.key,
    required this.showRename,
    required this.showDelete,
    required this.isRenaming,
    required this.isDeleting,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (showRename && showDelete) {
      return Row(
        children: [
          Expanded(
            child: _RenameButton(
              isLoading: isRenaming,
              onTap: onRename,
            ),
          ),
          Expanded(
            child: _DeleteButton(
              isLoading: isDeleting,
              onTap: onDelete,
            ),
          ),
        ],
      );
    }

    if (showRename) {
      return _RenameButton(isLoading: isRenaming, onTap: onRename);
    }

    return _DeleteButton(isLoading: isDeleting, onTap: onDelete);
  }
}

class _RenameButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _RenameButton({
    required this.onTap,
    required this.isLoading,
  });

  @override
  State<_RenameButton> createState() => _RenameButtonState();
}

class _RenameButtonState extends State<_RenameButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.isLoading) return;
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (widget.isLoading) return;
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressed ? PinitColors.aubergineSoft : PinitColors.aubergine,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PinitColors.cream,
                ),
              )
            else ...[
              const Icon(
                Icons.edit_rounded,
                size: 16,
                color: PinitColors.cream,
              ),
              const SizedBox(width: 8),
              Text(
                'Rename',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.cream,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeleteButtonState extends State<_DeleteButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.isLoading) return;
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (widget.isLoading) return;
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressed
            ? PinitColors.accent.withValues(alpha: 0.88)
            : PinitColors.accent,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PinitColors.cream,
                ),
              )
            else ...[
              const Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: PinitColors.cream,
              ),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.cream,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
