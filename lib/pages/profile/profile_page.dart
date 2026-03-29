import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:login/models/users.dart';
import 'package:login/models/locations.dart';
import 'package:login/supabase/service.dart';
import 'package:provider/provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/pages/auth_handler.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/models/notifications/base_notification.dart';
import 'widgets/profile_header.dart';
import 'widgets/hidden_gems_section.dart';
import 'widgets/trending_now_section.dart';
import 'widgets/collections_grid.dart';
import 'widgets/recent_activity_section.dart';
import 'widgets/notifications_sheet.dart';
import 'widgets/pinit_colors.dart';
import 'other_user_profile_page.dart';
import '../../widgets/profile/find_friends_section.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late StreamSubscription<BaseNotification> _notificationSubscription;
  double _scrollOffset = 0.0;
  int _selectedTab = 0;

  final List<String> _tabs = ['Pins', 'Collections', 'Discover'];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _notificationSubscription = FCMService().notificationStream.listen((_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = Provider.of<LocationListManager>(context, listen: false);
      manager.fetchSavedLocations();
      manager.fetchPopularLocations();
      manager.fetchHiddenGems();
    });
  }

  void _onScroll() {
    setState(() => _scrollOffset = _scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _notificationSubscription.cancel();
    super.dispose();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);
      await supabaseProvider.signOut();

      if (mounted) {
        Provider.of<UserDataProvider>(context, listen: false).clearUserData();
        Provider.of<LocationListManager>(context, listen: false).clearData();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthHandler()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context);
    final locationListManager = Provider.of<LocationListManager>(context);
    final UserModel? user = userDataProvider.supabaseUserData;

    if (userDataProvider.isLoading && user == null) {
      return _buildLoadingState();
    }

    if (user == null) {
      return _buildErrorState(userDataProvider);
    }

    final savedPins = locationListManager.savedLocations.keys.toList();
    final popularLocations = locationListManager.popularLocations;
    final hiddenGemLocations = locationListManager.hiddenGemLocations;
    final collapsedHeader = _scrollOffset > 120;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: collapsedHeader
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PinitColors.background,
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Don't interfere with scroll
                return false;
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // Collapsing Header
                  SliverToBoxAdapter(
                    child: ProfileHeader(
                      user: user,
                      scrollOffset: _scrollOffset,
                      onNotificationsTap: () => _showNotifications(context),
                      onSettingsTap: () => _showSettingsSheet(context),
                      unreadCount: FCMService().unreadCount,
                    ),
                  ),

                  // Tab Bar - Using SliverAppBar for better stability
                  SliverAppBar(
                    pinned: true,
                    elevation: 0,
                    backgroundColor: PinitColors.background,
                    automaticallyImplyLeading: false,
                    toolbarHeight: 56,
                    flexibleSpace: Container(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _tabs.asMap().entries.map((entry) {
                          final isSelected = entry.key == _selectedTab;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedTab = entry.key),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? PinitColors.primary.withOpacity(0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? PinitColors.primary
                                      : PinitColors.textSecondary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Content based on selected tab - using single SliverToBoxAdapter to avoid tree changes
                  SliverToBoxAdapter(
                    child: _buildTabContent(savedPins, popularLocations, hiddenGemLocations),
                  ),

                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),

            // Collapsed header overlay
            if (collapsedHeader)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildCollapsedHeader(user),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(List<LocationModel> savedPins, List<LocationModel> popularLocations, List<LocationModel> hiddenGemLocations) {
    switch (_selectedTab) {
      case 0:
        return Column(
          children: [
            // Taste Match Section
            // Hidden Gems
            HiddenGemsSection(
              locations: hiddenGemLocations,
            ),
            // Trending Now
            TrendingNowSection(
              locations: popularLocations,
            ),
            // Recent Activity
            const RecentActivitySection(),
          ],
        );
      case 1:
        return const CollectionsGrid();
      case 2:
        return _buildDiscoverSection();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDiscoverSection() {
    return Column(
      children: [
        const SizedBox(height: 8),
        FindFriendsSection(
          theme: Theme.of(context),
          onUserTap: (user) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => OtherUserProfilePage(user: user),
              ),
            );
          },
        ),
      ],
    );
  }


  Widget _buildCollapsedHeader(UserModel user) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF41133D),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: user.profileImageUrl != null &&
                        user.profileImageUrl!.isNotEmpty
                    ? NetworkImage(user.profileImageUrl!)
                    : const AssetImage('lib/assets/default_avatar.png')
                        as ImageProvider,
                fit: BoxFit.cover,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.name ?? 'Profile',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
          _buildNotificationButton(),
          const SizedBox(width: 8),
          _buildSettingsButton(),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    final unreadCount = FCMService().unreadCount;
    return GestureDetector(
      onTap: () => _showNotifications(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.notifications_outlined,
                size: 22,
                color: Colors.white,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
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
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
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

  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: () => _showSettingsSheet(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: const Center(
          child: Icon(
            Icons.more_horiz,
            size: 22,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: PinitColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: PinitColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading your taste...',
              style: TextStyle(
                fontSize: 16,
                color: PinitColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(UserDataProvider userDataProvider) {
    return Scaffold(
      backgroundColor: PinitColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: PinitColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.person_off_outlined,
                  size: 40,
                  color: PinitColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: PinitColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                userDataProvider.error ?? 'Unable to load your profile',
                style: const TextStyle(
                  fontSize: 15,
                  color: PinitColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => _handleSignOut(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: PinitColors.textPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationsSheet(),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: PinitColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PinitColors.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              _buildSettingsItem(
                icon: Icons.edit_outlined,
                label: 'Edit Profile',
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to edit profile
                },
              ),
              _buildSettingsItem(
                icon: Icons.tune_outlined,
                label: 'Preferences',
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to preferences
                },
              ),
              _buildSettingsItem(
                icon: Icons.share_outlined,
                label: 'Share Profile',
                onTap: () {
                  Navigator.pop(context);
                  // Share profile
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Divider(color: PinitColors.surfaceLight, height: 1),
              ),
              _buildSettingsItem(
                icon: Icons.logout_outlined,
                label: 'Sign Out',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _handleSignOut(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? PinitColors.accent : PinitColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
