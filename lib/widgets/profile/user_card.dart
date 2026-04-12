import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

enum _FollowStatus { idle, requested, following, blocked }

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
      final status = await service.users.getFollowStatus(widget.user.supabaseId!);
      if (mounted) {
        setState(() {
          _followStatus = switch (status) {
            'requested' => _FollowStatus.requested,
            'accepted' => _FollowStatus.following,
            'blocked' => _FollowStatus.blocked,
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
    if (_followStatus == _FollowStatus.blocked) return;
    HapticFeedback.selectionClick();
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          color: PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PinitColors.aubergine, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(4, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar ──
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: PinitColors.creamDeep, width: 2),
                boxShadow: PinitColors.subtleShadow,
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
            const SizedBox(width: 14),

            // ── Name + stats ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.name ?? 'Explorer',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PinitColors.aubergine,
                      letterSpacing: 0.2,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@${widget.user.email.split('@').first}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: PinitColors.mute,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        _StatItem(
                          value: _formatCount(widget.user.followersCount),
                          label: 'Followers',
                        ),
                        Container(
                          width: 1,
                          height: 14,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: PinitColors.creamDeep,
                        ),
                        _StatItem(
                          value: _formatCount(widget.user.followingCount),
                          label: 'Following',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

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
        color: PinitColors.creamSunk,
        child: const Icon(Icons.person, color: PinitColors.mute, size: 32),
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
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: PinitColors.aubergine,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: PinitColors.mute,
            letterSpacing: 0.12 * 9,
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
    final (Color bg, Color fg, String label) = switch (status) {
      _FollowStatus.idle => (PinitColors.aubergine, PinitColors.cream, 'Follow'),
      _FollowStatus.requested => (PinitColors.creamDeep, PinitColors.aubergineSoft, 'Requested'),
      _FollowStatus.following => (PinitColors.creamDeep, PinitColors.aubergine, 'Following'),
      _FollowStatus.blocked => (PinitColors.creamDeep, PinitColors.mute, 'Blocked'),
    };

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(fg),
                  ),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fg,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
