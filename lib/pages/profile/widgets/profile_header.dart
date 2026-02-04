import 'package:flutter/material.dart';
import 'package:login/models/users.dart';
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final opacity = (1 - (scrollOffset / 120)).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        gradient: PinitColors.warmGradient,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Column(
          children: [
            // Top actions row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionButton(
                    icon: Icons.notifications_outlined,
                    onTap: onNotificationsTap,
                    badgeCount: unreadCount,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.more_horiz,
                    onTap: onSettingsTap,
                  ),
                ],
              ),
            ),

            // Profile content (fades on scroll)
            Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + Name + Follow button row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Photo
                        _ProfileAvatar(user: user),
                        const SizedBox(width: 16),
                        
                        // Name + Bio + Location
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name ?? 'No Name',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: PinitColors.textPrimary,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              if (user.bio != null && user.bio!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  user.bio!.length > 80
                                      ? '${user.bio!.substring(0, 77)}...'
                                      : user.bio!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: PinitColors.textSecondary,
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                ),
                              ],
                              // Location display removed - not in UserModel
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Stats Row
                    _StatsRow(user: user),

                    const SizedBox(height: 20),

                    // Taste Chips
                    _TasteChips(),
                  ],
                ),
              ),
            ),
          ],
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: PinitColors.subtleShadow,
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                icon,
                size: 22,
                color: PinitColors.textSecondary,
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
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: PinitColors.primary.withOpacity(0.2),
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
        _StatItem(
          value: '0', // TODO: Get pins count from location provider
          label: 'Pins',
        ),
        const SizedBox(width: 24),
        _StatItem(
          value: user.followersCount.toString(),
          label: 'Followers',
          onTap: () {
            // Navigate to followers
          },
        ),
        const SizedBox(width: 24),
        _StatItem(
          value: user.followingCount.toString(),
          label: 'Following',
          onTap: () {
            // Navigate to following
          },
        ),
        const Spacer(),
        // Edit Profile button
        _EditProfileButton(),
      ],
    );
  }
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
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: PinitColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: PinitColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to edit profile
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: PinitColors.textPrimary.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: const Text(
          'Edit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: PinitColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TasteChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: Get actual taste data from user preferences
    final chips = [
      TasteChipData.cuisineTags[0], // Ramen
      TasteChipData.cuisineTags[1], // Veg
      TasteChipData.cuisineTags[2], // Wine Bars
      TasteChipData.vibeTags[0],    // Date night
      TasteChipData.vibeTags[2],    // Late night
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((chip) => _TasteChip(data: chip)).toList(),
    );
  }
}

class _TasteChip extends StatelessWidget {
  final TasteChipData data;

  const _TasteChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: data.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.emoji,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: data.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
