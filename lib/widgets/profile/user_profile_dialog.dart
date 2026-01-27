import 'package:flutter/material.dart';
import 'package:login/models/users.dart';
import 'package:login/supabase/service.dart';
import 'package:login/themes/app_colors.dart';
import 'package:login/themes/app_dimensions.dart';
import 'package:login/themes/app_typography.dart';
import 'package:provider/provider.dart';

class UserProfileDialog extends StatefulWidget {
  final UserModel user;

  const UserProfileDialog({
    super.key,
    required this.user,
  });

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

enum FollowStatus { idle, requested, following }

class _UserProfileDialogState extends State<UserProfileDialog> {
  FollowStatus _followStatus = FollowStatus.idle;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkInitialFollowStatus();
  }

  Future<void> _checkInitialFollowStatus() async {
    setState(() => _isLoading = true);
    try {
      if (widget.user.supabaseId == null) {
        print("Error: User supabaseId is null");
        if (mounted) setState(() => _followStatus = FollowStatus.idle);
        return;
      }
      final supabaseProvider = Provider.of<SupabaseService>(context, listen: false);
      final status = await supabaseProvider.users.getFollowStatus(widget.user.supabaseId!);
      if (mounted) {
        setState(() {
          if (status == 'requested' || status == 'pending') {
            _followStatus = FollowStatus.requested;
          } else if (status == 'accepted') {
            _followStatus = FollowStatus.following;
          } else {
            _followStatus = FollowStatus.idle;
          }
        });
      }
    } catch (e) {
      print("Error checking follow status: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFollowAction() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      if (widget.user.supabaseId == null) {
        print("Error: User supabaseId is null, cannot perform action");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cannot perform action: User ID is missing")),
          );
        }
        return;
      }

      final supabaseProvider = Provider.of<SupabaseService>(context, listen: false);

      if (_followStatus == FollowStatus.idle) {
        await supabaseProvider.users.followUser(widget.user.supabaseId!);
        if (mounted) setState(() => _followStatus = FollowStatus.requested);
      } else if (_followStatus == FollowStatus.requested || _followStatus == FollowStatus.following) {
        await supabaseProvider.users.unfollowUser(widget.user.supabaseId!);
        if (mounted) setState(() => _followStatus = FollowStatus.idle);
      }
    } catch (e) {
      print("Error performing follow/unfollow action: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Action failed: ${e.toString()}")),
        );
      }
      _checkInitialFollowStatus();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.radiusLarge,
      ),
      child: Padding(
        padding: AppSpacing.paddingLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProfileAvatar(),
            const SizedBox(height: AppSpacing.medium),
            _buildUserInfo(),
            const SizedBox(height: AppSpacing.large),
            _buildFollowButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 3,
        ),
      ),
      child: CircleAvatar(
        radius: 60,
        backgroundColor: AppColors.background,
        backgroundImage: widget.user.profileImageUrl != null &&
                widget.user.profileImageUrl!.isNotEmpty
            ? NetworkImage(widget.user.profileImageUrl!)
            : const AssetImage('lib/assets/default_avatar.png') as ImageProvider,
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      children: [
        Text(
          widget.user.name ?? 'New Explorer',
          style: AppTypography.headingMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '@${widget.user.username ?? _getUsernameFromEmail(widget.user.email)}',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.medium),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatItem('Followers', widget.user.followersCount),
            const SizedBox(width: AppSpacing.large),
            _buildStatItem('Following', widget.user.followingCount),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          _formatNumber(value),
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton() {
    String buttonText;
    Color buttonColor;
    Color textColor = AppColors.onPrimary;

    switch (_followStatus) {
      case FollowStatus.idle:
        buttonText = 'Follow';
        buttonColor = AppColors.primary;
        break;
      case FollowStatus.requested:
        buttonText = 'Requested';
        buttonColor = Colors.grey;
        textColor = Colors.black87;
        break;
      case FollowStatus.following:
        buttonText = 'Following';
        buttonColor = AppColors.secondary;
        break;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleFollowAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.medium,
            horizontal: AppSpacing.large,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusMedium,
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Text(
                buttonText,
                style: AppTypography.labelMedium.copyWith(color: textColor),
              ),
      ),
    );
  }

  String _getUsernameFromEmail(String email) {
    return email.split('@').first;
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }
}
