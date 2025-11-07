import 'package:flutter/material.dart';
import 'package:login/models/users.dart';
import 'package:login/supabase/service.dart';
import 'package:login/themes/app_colors.dart';
import 'package:login/themes/app_dimensions.dart';
import 'package:login/themes/app_typography.dart';
import 'package:provider/provider.dart';

class UserCard extends StatefulWidget {
  final UserModel user;

  const UserCard({
    super.key,
    required this.user,
  });

  @override
  State<UserCard> createState() => _UserCardState();
}

// Enum to represent follow button states
enum FollowStatus { idle, requested, following, unfollowing }

class _UserCardState extends State<UserCard> {
  FollowStatus _followStatus = FollowStatus.idle;
  bool _isLoading = false; // To handle loading state for API calls

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
          if (status == 'requested') {
            _followStatus = FollowStatus.requested;
          } else if (status == 'accepted') { // Assuming 'accepted' means following
            _followStatus = FollowStatus.following;
          } else {
            _followStatus = FollowStatus.idle;
          }
        });
      }
    } catch (e) {
      print("Error checking follow status: $e");
      // Optionally show an error to the user
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFollowAction() async {
    if (_isLoading) return; // Prevent multiple clicks
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
        // For both 'requested' and 'following', the action is to unfollow
        await supabaseProvider.users.unfollowUser(widget.user.supabaseId!);
        if (mounted) setState(() => _followStatus = FollowStatus.idle);
      }
    } catch (e) {
      print("Error performing follow/unfollow action: $e");
      // Optionally show an error to the user via a Snackbar
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Action failed: ${e.toString()}")),
        );
      }
      // Revert to previous state on error if necessary, or re-fetch status
      _checkInitialFollowStatus(); // Re-check status to be sure
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppElevation.small, // Reduced elevation
      margin: AppSpacing.paddingSmall, // Adjusted margin
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.radiusSmall, // Smaller radius
      ),
      child: Padding(
        padding: AppSpacing.paddingSmall, // Reduced padding
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ensure column takes minimum space
          children: [
            _buildProfileAvatar(),
            const SizedBox(height: AppSpacing.small), // Reduced spacing
            _buildUserInfo(),
            const SizedBox(height: AppSpacing.small), // Reduced spacing
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
          color: AppColors.primary.withOpacity(0.1),
          width: 1.5, // Thinner border
        ),
      ),
      child: CircleAvatar(
        radius: 30, // Smaller avatar
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
          style: AppTypography.bodySmall.copyWith( // Smaller text
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs), // Adjusted spacing
        Text(
          '@${_getUsernameFromEmail(widget.user.email)}',
          style: AppTypography.caption.copyWith(fontSize: 10), // Smaller text
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs), // Reduced spacing
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatItem('Followers', widget.user.followersCount),
            const SizedBox(width: AppSpacing.small), // Reduced spacing
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
          style: AppTypography.caption.copyWith( // Smaller text
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(fontSize: 9), // Smaller text
        ),
      ],
    );
  }

  Widget _buildFollowButton() {
    String buttonText;
    Color buttonColor;
    Color textColor = AppColors.onPrimary;
    bool isDisabled = _isLoading; // Disable button during API calls

    switch (_followStatus) {
      case FollowStatus.idle:
        buttonText = 'Follow';
        buttonColor = AppColors.primary;
        break;
      case FollowStatus.requested:
        buttonText = 'Requested';
        buttonColor = Colors.grey; // Greyed out
        textColor = Colors.black87;
        break;
      case FollowStatus.following:
        buttonText = 'Following';
        buttonColor = AppColors.secondary; // Or another color for 'Following'
        break;
      case FollowStatus.unfollowing: // Technically covered by isLoading, but good for clarity
        buttonText = '...';
        buttonColor = Colors.grey;
        isDisabled = true;
        break;
    }

    return ElevatedButton(
      onPressed: isDisabled ? null : _handleFollowAction,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: textColor,
        minimumSize: const Size(100, 30),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusSmall,
        ),
        elevation: 0,
      ),
      child: _isLoading && (_followStatus != FollowStatus.requested && _followStatus != FollowStatus.following) 
          ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(textColor))) 
          : Text(
              buttonText,
              style: AppTypography.labelSmall,
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