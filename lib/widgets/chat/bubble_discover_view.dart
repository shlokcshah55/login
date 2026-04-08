import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/service.dart';
import 'package:login/widgets/profile/user_card.dart';
import 'package:provider/provider.dart';

/// Shown when the search bar is focused but no query has been typed yet.
/// Two sections: "Your Hottest" bubbles and "Similar to you" users.
class BubbleDiscoverView extends StatelessWidget {
  final List<Bubble> bubbles;
  final void Function(Bubble) onBubbleTap;
  final void Function(UserModel)? onUserTap;

  const BubbleDiscoverView({
    Key? key,
    required this.bubbles,
    required this.onBubbleTap,
    this.onUserTap,
  }) : super(key: key);

  List<Bubble> get _hottestBubbles {
    final sorted = [...bubbles];
    sorted.sort((a, b) {
      final scoreA = a.compatibilityScore ?? 0;
      final scoreB = b.compatibilityScore ?? 0;
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      if (a.memberCount != b.memberCount) return b.memberCount.compareTo(a.memberCount);
      return b.groupLocations.length.compareTo(a.groupLocations.length);
    });
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
      children: [
        if (bubbles.isNotEmpty) ...[
          _SectionHeader(
            title: 'Your Hottest',
            subtitle: 'Bubbles you vibe with most',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: _hottestBubbles
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HotBubbleCard(
                          bubble: b,
                          onTap: () => onBubbleTap(b),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _SectionHeader(
          title: 'Similar to you',
          subtitle: 'People with matching taste',
        ),
        _SimilarUsersSection(onUserTap: onUserTap),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Rova',
              fontSize: 28,
              fontWeight: FontWeight.w100,
              color: PinitColors.aubergine,
              letterSpacing: 1.9,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: PinitColors.aubergineSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hot bubble card — compact, stat-focused, visually distinct from ChatGroupTile
// ─────────────────────────────────────────────────────────────────────────────

class _HotBubbleCard extends StatelessWidget {
  final Bubble bubble;
  final VoidCallback onTap;

  const _HotBubbleCard({required this.bubble, required this.onTap});

  static const List<Color> _avatarColors = [
    Color(0xFFB39DDB),
    Color(0xFF80CBC4),
    Color(0xFFFFCC80),
    Color(0xFFF48FB1),
    Color(0xFF90CAF9),
    Color(0xFFA5D6A7),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Mini avatar stack
                _MiniAvatarStack(
                  avatars: bubble.memberAvatars,
                  names: bubble.memberNames,
                  colors: _avatarColors,
                ),
                const SizedBox(width: 12),
                // Name + stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bubble.name,
                        style: const TextStyle(
                          fontFamily: 'Rova',
                          fontSize: 17,
                          fontWeight: FontWeight.w100,
                          color: PinitColors.aubergine,
                          letterSpacing: 0.8,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _MiniStat(
                            icon: Icons.people_outline_rounded,
                            label: '${bubble.memberCount} member${bubble.memberCount == 1 ? '' : 's'}',
                          ),
                          const SizedBox(width: 10),
                          _MiniStat(
                            icon: Icons.place_outlined,
                            label: '${bubble.groupLocations.length} place${bubble.groupLocations.length == 1 ? '' : 's'}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Score badge
                if (bubble.compatibilityScore != null) ...[
                  const SizedBox(width: 10),
                  _LargeScoreBadge(score: bubble.compatibilityScore!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini avatar stack (32px, up to 3)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniAvatarStack extends StatelessWidget {
  final List<String> avatars;
  final List<String> names;
  final List<Color> colors;

  const _MiniAvatarStack({
    required this.avatars,
    required this.names,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final items = avatars.take(3).toList();
    if (items.isEmpty) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: PinitColors.creamSunk,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.people_outline_rounded, size: 14, color: PinitColors.mute),
      );
    }

    const double size = 32.0;
    const double overlap = 10.0;
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
                border: Border.all(color: PinitColors.cream, width: 1.5),
                color: colors[i % colors.length],
              ),
              child: ClipOval(
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _Initial(initial: initial),
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
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }
    return const Icon(Icons.person, size: 14, color: Colors.white);
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: PinitColors.mute),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PinitColors.mute,
          ),
        ),
      ],
    );
  }
}

class _LargeScoreBadge extends StatelessWidget {
  final int score;
  const _LargeScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = PinitColors.matchIndicator(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score%',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.0,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'MATCH',
            style: GoogleFonts.dmSans(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Similar users section
// ─────────────────────────────────────────────────────────────────────────────

class _SimilarUsersSection extends StatefulWidget {
  final void Function(UserModel)? onUserTap;
  const _SimilarUsersSection({this.onUserTap});

  @override
  State<_SimilarUsersSection> createState() => _SimilarUsersSectionState();
}

class _SimilarUsersSectionState extends State<_SimilarUsersSection> {
  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final service = Provider.of<SupabaseService>(context, listen: false);
      final users = await service.users.getSuggestedUsers();
      if (mounted) setState(() => _users = users);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PinitColors.aubergine,
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Text(
          'No similar people found right now — check back later.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: PinitColors.aubergineSoft,
            height: 1.5,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _users
            .map((user) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: UserCard(
                    user: user,
                    onTap: widget.onUserTap,
                  ),
                ))
            .toList(),
      ),
    );
  }
}
