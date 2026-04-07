import 'package:flutter/material.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/service.dart';
import 'package:provider/provider.dart';

class UserCard extends StatefulWidget {
  final UserModel user;
  final Function(UserModel)? onTap;

  const UserCard({
    super.key,
    required this.user,
    this.onTap,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

enum _FollowStatus { idle, requested, following }

class _UserCardState extends State<UserCard> {
  _FollowStatus _followStatus = _FollowStatus.idle;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    setState(() => _isLoading = true);
    try {
      if (widget.user.supabaseId == null) return;
      final service = Provider.of<SupabaseService>(context, listen: false);
      final status =
          await service.users.getFollowStatus(widget.user.supabaseId!);
      if (mounted) {
        setState(() {
          _followStatus = switch (status) {
            'requested' => _FollowStatus.requested,
            'accepted' => _FollowStatus.following,
            _ => _FollowStatus.idle,
          };
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFollowAction() async {
    if (_isLoading || widget.user.supabaseId == null) return;
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<SupabaseService>(context, listen: false);
      if (_followStatus == _FollowStatus.idle) {
        await service.users.followUser(widget.user.supabaseId!);
        if (mounted) setState(() => _followStatus = _FollowStatus.requested);
      } else {
        await service.users.unfollowUser(widget.user.supabaseId!);
        if (mounted) setState(() => _followStatus = _FollowStatus.idle);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap != null ? () => widget.onTap!(widget.user) : null,
      child: Container(
        decoration: BoxDecoration(
          color: PinitColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: PinitColors.cardShadow,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Avatar ──
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: PinitColors.surfaceLight,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: widget.user.profileImageUrl != null &&
                        widget.user.profileImageUrl!.isNotEmpty
                    ? Image.network(
                        widget.user.profileImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultAvatar(),
                      )
                    : _defaultAvatar(),
              ),
            ),
            const SizedBox(height: 10),

            // ── Name ──
            Text(
              widget.user.name ?? 'Explorer',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PinitColors.textPrimary,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            // ── Username ──
            const SizedBox(height: 2),
            Text(
              '@${widget.user.email.split('@').first}',
              style: const TextStyle(
                fontSize: 11,
                color: PinitColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            // ── Stats ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatItem(
                    value: _formatCount(widget.user.followersCount),
                    label: 'followers'),
                Container(
                  width: 1,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: PinitColors.surfaceLight,
                ),
                _StatItem(
                    value: _formatCount(widget.user.followingCount),
                    label: 'following'),
              ],
            ),

            const SizedBox(height: 12),

            // ── Follow button ──
            _FollowButton(
              status: _followStatus,
              isLoading: _isLoading,
              onTap: _handleFollowAction,
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() => Container(
        color: PinitColors.surfaceLight,
        child: const Icon(Icons.person, color: PinitColors.textMuted, size: 32),
      );

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: PinitColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: PinitColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  final _FollowStatus status;
  final bool isLoading;
  final VoidCallback onTap;

  const _FollowButton({
    required this.status,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (String label, Color bg, Color fg) = switch (status) {
      _FollowStatus.idle => ('Follow', PinitColors.primary, Colors.white),
      _FollowStatus.requested => (
          'Requested',
          PinitColors.surfaceLight,
          PinitColors.textSecondary
        ),
      _FollowStatus.following => (
          'Following',
          PinitColors.surfaceLight,
          PinitColors.primary
        ),
    };

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: status == _FollowStatus.idle
              ? [
                  BoxShadow(
                    color: PinitColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Center(
          child: isLoading && status == _FollowStatus.idle
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(fg),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: 0.1,
                  ),
                ),
        ),
      ),
    );
  }
}
