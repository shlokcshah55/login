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
                      onSettingsTap: () => _showSettingsSheet(context, user),
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
                    flexibleSpace: _buildPinnedTabs(),
                  ),

                  // Content based on selected tab - using single SliverToBoxAdapter to avoid tree changes
                  SliverToBoxAdapter(
                    child: _buildTabContent(
                        savedPins, popularLocations, hiddenGemLocations),
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

  Widget _buildTabContent(
      List<LocationModel> savedPins,
      List<LocationModel> popularLocations,
      List<LocationModel> hiddenGemLocations) {
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
                color: Colors.white.withValues(alpha: 0.5),
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
          _buildSettingsButton(user),
        ],
      ),
    );
  }

  Widget _buildPinnedTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          boxShadow: PinitColors.subtleShadow,
        ),
        child: Row(
          children: _tabs.asMap().entries.map((entry) {
            final isSelected = entry.key == _selectedTab;
            final isLast = entry.key == _tabs.length - 1;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (_selectedTab == entry.key) return;
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTab = entry.key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected ? PinitColors.subtleShadow : null,
                      ),
                      child: Text(
                        entry.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected
                              ? PinitColors.textPrimary
                              : PinitColors.textSecondary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotificationButton() {
    final unreadCount = FCMService().unreadCount;
    return _buildHeaderActionButton(
      icon: Icons.notifications_outlined,
      badgeCount: unreadCount,
      onTap: () => _showNotifications(context),
    );
  }

  Widget _buildSettingsButton(UserModel user) {
    return _buildHeaderActionButton(
      icon: Icons.more_horiz_rounded,
      onTap: () => _showSettingsSheet(context, user),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
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

  void _showSettingsSheet(BuildContext context, UserModel user) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ProfileSettingsSheet(
        user: user,
        onEditProfile: () {
          Navigator.pop(sheetContext);
          // Navigate to edit profile
        },
        onPreferences: () {
          Navigator.pop(sheetContext);
          // Navigate to preferences
        },
        onShareProfile: () {
          Navigator.pop(sheetContext);
          // Share profile
        },
        onSignOut: () {
          Navigator.pop(sheetContext);
          _handleSignOut(context);
        },
      ),
    );
  }
}

class _ProfileSettingsSheet extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEditProfile;
  final VoidCallback onPreferences;
  final VoidCallback onShareProfile;
  final VoidCallback onSignOut;

  const _ProfileSettingsSheet({
    required this.user,
    required this.onEditProfile,
    required this.onPreferences,
    required this.onShareProfile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          12, 0, 12, bottomPadding > 0 ? bottomPadding : 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFCFB),
                PinitColors.background,
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 32,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: PinitColors.textMuted.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ProfileSettingsIntro(user: user),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileSettingsCard(
                          icon: Icons.draw_rounded,
                          title: 'Edit Profile',
                          subtitle: 'Photo, bio, and top vibes',
                          backgroundColor: const Color(0xFFFFF1EC),
                          iconBackgroundColor: PinitColors.accentSoft,
                          iconColor: PinitColors.primary,
                          onTap: onEditProfile,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProfileSettingsCard(
                          icon: Icons.tune_rounded,
                          title: 'Preferences',
                          subtitle: 'Taste, alerts, and privacy',
                          backgroundColor: const Color(0xFFF5F1EC),
                          iconBackgroundColor: const Color(0xFFE8E0D7),
                          iconColor: PinitColors.textPrimary,
                          onTap: onPreferences,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ProfileSettingsRow(
                    icon: Icons.ios_share_rounded,
                    title: 'Share Profile',
                    subtitle: 'Send your public profile in one tap',
                    backgroundColor: Colors.white.withValues(alpha: 0.84),
                    iconBackgroundColor: const Color(0xFFE9EDF5),
                    iconColor: const Color(0xFF5D6B89),
                    onTap: onShareProfile,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(
                      color: PinitColors.surfaceLight,
                      height: 1,
                    ),
                  ),
                  _ProfileSettingsRow(
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    subtitle: 'Log out of this device',
                    backgroundColor: const Color(0xFFFFF5F2),
                    iconBackgroundColor: const Color(0xFFFFE5DF),
                    iconColor: PinitColors.error,
                    textColor: PinitColors.error,
                    onTap: onSignOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSettingsIntro extends StatelessWidget {
  final UserModel user;

  const _ProfileSettingsIntro({required this.user});

  @override
  Widget build(BuildContext context) {
    final imageProvider = user.profileImageUrl != null &&
            user.profileImageUrl!.isNotEmpty
        ? NetworkImage(user.profileImageUrl!)
        : const AssetImage('lib/assets/default_avatar.png') as ImageProvider;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your space',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.primary.withValues(alpha: 0.88),
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.name ?? 'Your profile',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.textPrimary,
                    letterSpacing: -0.4,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Small changes here shape how people discover you on Pinit.',
                  style: TextStyle(
                    fontSize: 13,
                    color: PinitColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _ProfileSettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          height: 146,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: PinitColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PinitColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: PinitColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Color? textColor;
  final VoidCallback onTap;

  const _ProfileSettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = textColor ?? PinitColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: PinitColors.subtleShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: -0.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: PinitColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: titleColor.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
