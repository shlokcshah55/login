import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/bubble.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

class ChatGroupTile extends StatelessWidget {
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

  static const List<Color> _avatarColors = [
    Color(0xFFB39DDB),
    Color(0xFF80CBC4),
    Color(0xFFFFCC80),
    Color(0xFFF48FB1),
    Color(0xFF90CAF9),
    Color(0xFFA5D6A7),
  ];

  String _membersSubtitle() {
    if (bubble.memberNames.isEmpty) {
      return '${bubble.memberCount} member${bubble.memberCount == 1 ? '' : 's'}';
    }
    const maxShown = 2;
    final shown = bubble.memberNames.take(maxShown).join(', ');
    final extra = bubble.memberNames.length - maxShown;
    return extra > 0 ? '$shown +$extra' : shown;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PinitColors.cream,
        border: Border.fromBorderSide(
          BorderSide(color: PinitColors.aubergine, width: 1.5),
        ),
        borderRadius: BorderRadius.all(Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            color: PinitColors.aubergine,
            blurRadius: 0,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Last message strip ──
            GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (bubble.lastMessageTime.isNotEmpty)
                    Container(
                      color: PinitColors.creamSunk,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: PinitColors.mute,
                          ),
                          const SizedBox(width: 5),
                          if (bubble.lastMessage.isNotEmpty && bubble.lastMessage != 'Tap to view locations') ...[
                            Expanded(
                              child: Text(
                                bubble.lastMessage,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: PinitColors.mute,
                                  fontWeight: FontWeight.w500,
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
                              color: PinitColors.mute,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // ── Body ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar stack
                    _AvatarStack(
                      avatars: bubble.memberAvatars,
                      names: bubble.memberNames,
                      colors: _avatarColors,
                    ),
                    const SizedBox(width: 14),
                    // Name + members
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
                              if (bubble.compatibilityScore != null) ...[
                                const SizedBox(width: 8),
                                _ScoreBadge(score: bubble.compatibilityScore!),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _membersSubtitle(),
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: PinitColors.mute,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Chat button
                    _ChatButton(onTap: onOpenChat ?? onTap),
                  ],
                ),
              ),
            ],
          ),
        ),

            // ── Activate button ──
            _ActivateButton(onTap: onActivateBubble ?? () {}),
          ],
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
  final VoidCallback onTap;
  const _ChatButton({required this.onTap});

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
          color: _pressed ? PinitColors.creamDeep : PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PinitColors.creamDeep, width: 1),
        ),
        child: const Icon(
          Icons.chat_bubble_outline_rounded,
          size: 18,
          color: PinitColors.aubergine,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ActivateButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ActivateButton({required this.onTap});

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
        color:
            _pressed ? PinitColors.aubergineSoft : PinitColors.aubergine,
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
