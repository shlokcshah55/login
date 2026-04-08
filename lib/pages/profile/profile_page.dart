import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

  final List<String> _tabs = ['Hot', 'Collections', 'People'];

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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
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
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: PinitColors.cream,
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) => false,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: ProfileHeader(
                      user: user,
                      scrollOffset: _scrollOffset,
                      onNotificationsTap: () => _showNotifications(context),
                      onSettingsTap: () => _showSettingsSheet(context, user),
                      unreadCount: FCMService().unreadCount,
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),
                  SliverAppBar(
                    pinned: true,
                    elevation: 4,
                    shadowColor: PinitColors.aubergine.withValues(alpha: 0.06),
                    backgroundColor: PinitColors.cream,
                    automaticallyImplyLeading: false,
                    toolbarHeight: 40,
                    flexibleSpace: _buildPinnedTabs(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildTabContent(
                        user, savedPins, popularLocations, hiddenGemLocations),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
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
      UserModel user,
      List<LocationModel> savedPins,
      List<LocationModel> popularLocations,
      List<LocationModel> hiddenGemLocations) {
    switch (_selectedTab) {
      case 0:
        return Column(
          children: [
            HiddenGemsSection(locations: hiddenGemLocations),
            TrendingNowSection(locations: popularLocations),
            const RecentActivitySection(),
          ],
        );
      case 1:
        return CollectionsGrid(
          generatedCollections: user.generatedCollections,
        );
      case 2:
        return _buildDiscoverSection();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDiscoverSection() {
    return FindFriendsSection(
      theme: Theme.of(context),
      onUserTap: (user) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OtherUserProfilePage(user: user),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedHeader(UserModel user) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 24,
        right: 24,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        color: PinitColors.aubergine,
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
                color: PinitColors.creamDeep.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.name ?? 'Profile',
              style: const TextStyle(
                fontFamily: 'Rova',
                fontSize: 20,
                fontWeight: FontWeight.w100,
                color: PinitColors.cream,
                letterSpacing: 1.9,
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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _tabs.asMap().entries.map((entry) {
          final isSelected = entry.key == _selectedTab;
          final isLast = entry.key == _tabs.length - 1;

          return Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: GestureDetector(
              onTap: () {
                if (_selectedTab == entry.key) return;
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = entry.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? PinitColors.aubergine : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 20,
                    fontWeight: FontWeight.w100,
                    color: isSelected ? PinitColors.cream : PinitColors.mute,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationButton() {
    final unreadCount = FCMService().unreadCount;
    return _buildHeaderActionButton(
      icon: Icons.notifications_outlined,
      badgeCount: unreadCount,
      onTap: () => _showNotifications(context),
      onDark: true,
    );
  }

  Widget _buildSettingsButton(UserModel user) {
    return _buildHeaderActionButton(
      icon: Icons.more_horiz_rounded,
      onTap: () => _showSettingsSheet(context, user),
      onDark: true,
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
    bool onDark = false,
  }) {
    final bg = onDark
        ? PinitColors.cream.withValues(alpha: 0.12)
        : PinitColors.creamSunk;
    final borderColor = onDark
        ? PinitColors.cream.withValues(alpha: 0.2)
        : PinitColors.creamDeep;
    final iconColor = onDark ? PinitColors.cream : PinitColors.aubergine;

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
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: onDark ? null : PinitColors.subtleShadow,
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(icon, size: 20, color: iconColor),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: const BoxDecoration(
                      color: PinitColors.accent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                        minWidth: 18, minHeight: 18),
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

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: PinitColors.cream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: PinitColors.aubergine,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(PinitColors.cream),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading your taste...',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                color: PinitColors.aubergineSoft,
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
      backgroundColor: PinitColors.cream,
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
                  color: PinitColors.creamSunk,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.person_off_outlined,
                  size: 40,
                  color: PinitColors.mute,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: const TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.aubergine,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                userDataProvider.error ?? 'Unable to load your profile',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: PinitColors.aubergineSoft,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => _handleSignOut(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: PinitColors.aubergine,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Sign Out',
                    style: GoogleFonts.dmSans(
                      color: PinitColors.cream,
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
        onEditProfile: () => Navigator.pop(sheetContext),
        onPreferences: () => Navigator.pop(sheetContext),
        onShareProfile: () => Navigator.pop(sheetContext),
        onSignOut: () {
          Navigator.pop(sheetContext);
          _handleSignOut(context);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Sheet
// ─────────────────────────────────────────────────────────────────────────────

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
            color: PinitColors.cream,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
            boxShadow: PinitColors.elevatedShadow,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: PinitColors.creamDeep,
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
                          onTap: onEditProfile,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ProfileSettingsCard(
                          icon: Icons.tune_rounded,
                          title: 'Preferences',
                          subtitle: 'Taste, alerts, and privacy',
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
                    onTap: onShareProfile,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(
                      color: PinitColors.creamDeep,
                      height: 1,
                    ),
                  ),
                  _ProfileSettingsRow(
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    subtitle: 'Log out of this device',
                    isDestructive: true,
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
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
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
                color: PinitColors.creamDeep,
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
                  'YOUR SPACE',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.aubergineSoft,
                    letterSpacing: 0.12 * 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.name ?? 'Your profile',
                  style: const TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.8,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Small changes here shape how people discover you on Pinit.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: PinitColors.aubergineSoft,
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
  final VoidCallback onTap;

  const _ProfileSettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          height: 146,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PinitColors.creamDeep,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: PinitColors.aubergine, size: 20),
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PinitColors.aubergine,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.aubergineSoft,
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
  final bool isDestructive;
  final VoidCallback onTap;

  const _ProfileSettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor =
        isDestructive ? PinitColors.accent : PinitColors.aubergine;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDestructive
                ? const Color(0xFFFFF5F2)
                : PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PinitColors.creamDeep,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: titleColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: -0.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: PinitColors.aubergineSoft,
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
