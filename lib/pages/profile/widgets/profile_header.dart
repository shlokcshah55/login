import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/users.dart';
import 'package:login/supabase/supabase_client.dart';
import 'pinit_colors.dart';
import 'creator_tag.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel user;
  final double scrollOffset;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;
  final int unreadCount;
  final int followersCount;
  final int followingCount;
  final int pinsCount;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;
  final Key? notificationsSpotlightKey;
  final Key? settingsSpotlightKey;

  const ProfileHeader({
    Key? key,
    required this.user,
    required this.scrollOffset,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.unreadCount,
    required this.followersCount,
    required this.followingCount,
    required this.pinsCount,
    this.onFollowersTap,
    this.onFollowingTap,
    this.notificationsSpotlightKey,
    this.settingsSpotlightKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final opacity = (1 - (scrollOffset / 120)).clamp(0.0, 1.0);

    return Container(
      color: PinitColors.aubergine,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Opacity(
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ProfileAvatar(user: user),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  user.name ?? 'No Name',
                                  style: const TextStyle(
                                    fontFamily: 'Rova',
                                    fontFamilyFallback: ['Naria'],
                                    fontSize: 28,
                                    fontWeight: FontWeight.w100,
                                    color: PinitColors.cream,
                                    letterSpacing: 1.7,
                                    height: 1.05,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.verified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 22,
                                  color: PinitColors.cream,
                                ),
                              ],
                            ],
                          ),
                          if (user.verified) ...[
                            const SizedBox(height: 6),
                            const CreatorTag(),
                          ],
                          if (user.bio != null && user.bio!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              user.bio!.length > 60
                                  ? '${user.bio!.substring(0, 57)}...'
                                  : user.bio!,
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                color: PinitColors.cream.withValues(alpha: 0.7),
                                height: 1.45,
                              ),
                              maxLines: 2,
                            ),
                          ],
                          const SizedBox(height: 10),
                          _StatsRow(
                            followersCount: followersCount,
                            followingCount: followingCount,
                            pinsCount: pinsCount,
                            onFollowersTap: onFollowersTap,
                            onFollowingTap: onFollowingTap,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        RepaintBoundary(
                          key: notificationsSpotlightKey,
                          child: _ActionButton(
                            icon: Icons.notifications_outlined,
                            onTap: onNotificationsTap,
                            badgeCount: unreadCount,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RepaintBoundary(
                          key: settingsSpotlightKey,
                          child: _ActionButton(
                            icon: Icons.more_horiz,
                            onTap: onSettingsTap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PinitColors.cream.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: PinitColors.cream.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  icon,
                  size: 19,
                  color: PinitColors.cream,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: PinitColors.accent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        badgeCount > 9 ? '9+' : badgeCount.toString(),
                        style: GoogleFonts.dmSans(
                          color: PinitColors.cream,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final UserModel user;

  const _ProfileAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'profile_avatar',
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: PinitColors.cream.withValues(alpha: 0.3),
            width: 2.5,
          ),
          boxShadow: PinitColors.cardShadow,
        ),
        child: ClipOval(
          child:
              user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                  ? Image.network(
                      user.profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultAvatar(),
                    )
                  : _defaultAvatar(),
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: PinitColors.creamSunk,
      child: const Icon(
        Icons.person,
        size: 40,
        color: PinitColors.mute,
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int followersCount;
  final int followingCount;
  final int pinsCount;
  final VoidCallback? onFollowersTap;
  final VoidCallback? onFollowingTap;

  const _StatsRow({
    required this.followersCount,
    required this.followingCount,
    required this.pinsCount,
    this.onFollowersTap,
    this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          _StatItem(value: pinsCount.toString(), label: 'Pins'),
          _buildDivider(),
          _StatItem(
            value: followersCount.toString(),
            label: 'Followers',
            onTap: onFollowersTap,
          ),
          _buildDivider(),
          _StatItem(
            value: followingCount.toString(),
            label: 'Following',
            onTap: onFollowingTap,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(
        width: 1,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: PinitColors.cream.withValues(alpha: 0.25),
      );
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatItem({
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: PinitColors.cream,
            letterSpacing: -0.4,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PinitColors.cream.withValues(alpha: 0.55),
            letterSpacing: 0.12 * 11,
          ),
        ),
      ],
    );

    if (onTap == null) return column;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: column,
    );
  }
}

class _TasteChips extends StatefulWidget {
  @override
  State<_TasteChips> createState() => _TasteChipsState();
}

class _TasteChipsState extends State<_TasteChips> {
  static const Map<String, String> _emojiMap = {
    'halal': '☪️',
    'vegan': '🌱',
    'gluten-free': '🌾',
    'vegetarian': '🥗',
    'dairy-free': '🥛',
    'nut-free': '🥜',
    'cafe': '☕',
    'casual': '😊',
    'cozy': '🧸',
    'coffee shop': '☕',
    'bar': '🍸',
    'elegant': '🥂',
    'fine dining': '🍽️',
    'food truck': '🚚',
    'hole in the wall': '🕳️',
    'late night': '🌙',
    'live music': '🎵',
    'bougie': '⭐',
    'modern': '✨',
    'fast food': '🍔',
    'quiet': '🤫',
    'romantic': '🌹',
    'sports bar': '🏈',
    'trendy': '🔥',
    'takeout friendly': '📦',
    'pub': '🍺',
    'shop': '🛒',
    'brunch': '🥞',
    'outdoor dining': '🌿',
    'wavy': '🌊',
    'bossman': '👑',
  };

  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _fetchTopVibes();
  }

  Future<void> _fetchTopVibes() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;

    try {
      final response = await SupabaseClientManager().client.rpc(
        'get_user_top_vibes',
        params: {'p_user_id': userId},
      );

      final tags = (response as List)
          .map((e) => (e['tag'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .toList();

      if (mounted) setState(() => _tags = tags);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags.map((tag) {
        final emoji = _emojiMap[tag.toLowerCase()] ?? '🍴';
        final isWavy = tag.toLowerCase() == 'wavy';
        return _TasteChip(label: tag, emoji: emoji, isWavy: isWavy);
      }).toList(),
    );
  }
}

class _TasteChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isWavy;

  const _TasteChip({
    required this.label,
    required this.emoji,
    this.isWavy = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isWavy ? PinitColors.accent : PinitColors.aubergine;
    final textColor = PinitColors.cream;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.12 * 10,
            ),
          ),
        ],
      ),
    );
  }
}
