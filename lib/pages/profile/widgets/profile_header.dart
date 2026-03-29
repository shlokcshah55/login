import 'package:flutter/material.dart';
import 'package:login/models/users.dart';
import 'package:login/supabase/supabase_client.dart';
import 'pinit_colors.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel user;
  final double scrollOffset;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;
  final int unreadCount;

  const ProfileHeader({
    Key? key,
    required this.user,
    required this.scrollOffset,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.unreadCount,
  }) : super(key: key);

  static const Color _plum = Color(0xFF41133D);
  static const Color _plumLight = Color(0xFF6B2465);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final opacity = (1 - (scrollOffset / 120)).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_plum, _plumLight],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Opacity(
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
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
                          Text(
                            user.name ?? 'No Name',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                          if (user.bio != null && user.bio!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              user.bio!.length > 60
                                  ? '${user.bio!.substring(0, 57)}...'
                                  : user.bio!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.7),
                                height: 1.3,
                              ),
                              maxLines: 2,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _StatsRow(user: user),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        _ActionButton(
                          icon: Icons.notifications_outlined,
                          onTap: onNotificationsTap,
                          badgeCount: unreadCount,
                        ),
                        const SizedBox(height: 8),
                        _ActionButton(
                          icon: Icons.more_horiz,
                          onTap: onSettingsTap,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _TasteChips(),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                icon,
                size: 20,
                color: Colors.white,
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
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
                      style: const TextStyle(
                        color: Colors.white,
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
            color: Colors.white.withOpacity(0.6),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
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
      color: PinitColors.surfaceLight,
      child: const Icon(
        Icons.person,
        size: 40,
        color: PinitColors.textMuted,
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final UserModel user;

  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(value: '0', label: 'Pins'),
        _buildDivider(),
        _StatItem(value: user.followersCount.toString(), label: 'Followers'),
        _buildDivider(),
        _StatItem(value: user.followingCount.toString(), label: 'Following'),
      ],
    );
  }

  Widget _buildDivider() => Container(
        width: 1,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withOpacity(0.25),
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}


class _TasteChips extends StatefulWidget {
  @override
  State<_TasteChips> createState() => _TasteChipsState();
}

class _TasteChipsState extends State<_TasteChips> {
  static const Map<String, String> _emojiMap = {
    // Dietary
    'halal': '☪️',
    'vegan': '🌱',
    'gluten-free': '🌾',
    'vegetarian': '🥗',
    'dairy-free': '🥛',
    'nut-free': '🥜',
    // Vibes
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
    'michelin starred': '⭐',
    'modern': '✨',
    'fast food': '🍔',
    'quiet': '🤫',
    'romantic': '🌹',
    'sports bar': '🏈',
    'trendy': '🔥',
    'takeout friendly': '📦',
    'pub': '🍺',
    'grocery store': '🛒',
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
    print('[TasteChips] userId: $userId');
    if (userId == null) {
      print('[TasteChips] No user, aborting');
      return;
    }

    try {
      print('[TasteChips] Calling get_user_top_vibes(p_user_id: $userId)');
      final response = await SupabaseClientManager().client.rpc(
        'get_user_top_vibes',
        params: {'p_user_id': userId},
      );

      print('[TasteChips] Raw response: $response');

      final tags = (response as List)
          .map((e) => (e['tag'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .toList();

      print('[TasteChips] Parsed tags: $tags');

      if (mounted) setState(() => _tags = tags);
    } catch (e, stack) {
      print('[TasteChips] Error: $e');
      print('[TasteChips] Stack: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tags.isEmpty) return const SizedBox.shrink();

    const colors = [
      PinitColors.chipRamen,
      PinitColors.chipVeg,
      PinitColors.chipWine,
      PinitColors.chipDateNight,
      PinitColors.chipCheapEats,
      PinitColors.chipLateNight,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tags.asMap().entries.map((entry) {
        final emoji = _emojiMap[entry.value.toLowerCase()] ?? '🍴';
        return _TasteChip(
          label: entry.value,
          emoji: emoji,
          color: colors[entry.key % colors.length],
        );
      }).toList(),
    );
  }
}

class _TasteChip extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;

  const _TasteChip({required this.label, required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PinitColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
