import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/users.dart';
import 'package:login/models/locations.dart';
import 'package:login/supabase/service.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'package:provider/provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/pages/auth_handler.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/models/notifications/base_notification.dart';
import 'widgets/profile_header.dart';
import 'widgets/hidden_gems_section.dart';
import 'widgets/collections_grid.dart';
import 'widgets/recent_activity_section.dart';
import 'widgets/pinit_colors.dart';
import 'widgets/profile_completion_checklist_card.dart';
import 'edit_profile_page.dart';
import 'preferences_page.dart';
import 'other_user_profile_page.dart';
import 'user_list_page.dart';
import '../../widgets/profile/find_friends_section.dart';
import '../../widgets/profile/notifications_popover.dart';
import 'package:login/utils/route_open_guard.dart';

class ProfilePage extends StatefulWidget {
  final bool isActive;

  const ProfilePage({
    Key? key,
    this.isActive = true,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late StreamSubscription<BaseNotification> _notificationSubscription;
  double _scrollOffset = 0.0;
  int _selectedTab = 0;
  int _followersCount = 0;
  int _followingCount = 0;
  final List<String> _tabs = ['Hot', 'Eat-Lists', 'People'];
  final _eatListsAnchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _notificationSubscription = FCMService().notificationStream.listen((_) {
      if (mounted) {
        setState(() {});
        _loadFollowCounts();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final manager = Provider.of<LocationListManager>(context, listen: false);
      manager.fetchSavedLocations();
      manager.fetchHiddenGems();
      _loadFollowCounts();
    });
  }

  Future<void> _loadFollowCounts() async {
    try {
      final service = Provider.of<SupabaseService>(context, listen: false);
      final results = await Future.wait([
        service.users.getFollowers(),
        service.users.getFollowingList(),
      ]);
      if (!mounted) return;
      setState(() {
        _followersCount = results[0].length;
        _followingCount = results[1].length;
      });
    } catch (_) {
      // Best-effort refresh; leave prior counts in place on error.
    }
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
        unawaited(
          AppFeedback.showError(
            context,
            title: 'Couldn’t sign out',
            message: 'Please try again in a moment.',
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
    final collapsedHeader = _scrollOffset > 120;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: PinitColors.cream,
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) => false,
              child: RefreshIndicator(
                onRefresh: _loadFollowCounts,
                color: PinitColors.aubergine,
                backgroundColor: PinitColors.cream,
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
                        followersCount: _followersCount,
                        followingCount: _followingCount,
                        pinsCount: savedPins.length,
                        onFollowersTap: () => _openFollowers(context),
                        onFollowingTap: () => _openFollowing(context),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 20),
                    ),
                    SliverToBoxAdapter(
                      child: ProfileCompletionChecklistCard(
                        onSelectProfileTab: (i) {
                          if (!mounted) return;
                          setState(() => _selectedTab = i);
                        },
                        onRequestScrollToEatLists: _scrollToEatLists,
                      ),
                    ),
                    SliverAppBar(
                      pinned: true,
                      elevation: 4,
                      shadowColor:
                          PinitColors.aubergine.withValues(alpha: 0.06),
                      backgroundColor: PinitColors.cream,
                      automaticallyImplyLeading: false,
                      toolbarHeight: 20,
                      flexibleSpace: _buildPinnedTabs(),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        key: _eatListsAnchorKey,
                        height: 1,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _buildTabContent(
                        user,
                        savedPins,
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
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
  ) {
    switch (_selectedTab) {
      case 0:
        return Column(
          children: [
            HottestSharedPlacesSection(
              locations:
                  context.watch<LocationListManager>().hiddenGemLocations,
            ),
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

  void _scrollToEatLists() {
    if (!mounted) return;
    // Switch tabs first so the correct content exists below the pinned header.
    if (_selectedTab != 1) {
      setState(() => _selectedTab = 1);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _eatListsAnchorKey.currentContext;
      if (ctx == null) return;
      // Leave some breathing room below the pinned tab bar.
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.06,
      );
    });
  }

  Widget _buildDiscoverSection() {
    return FindFriendsSection(
      theme: Theme.of(context),
      onUserTap: (user) {
        final userKey = user.supabaseId ?? user.email;
        unawaited(
          RouteOpenGuard.run<void>(
            'other-user-profile:$userKey',
            () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (context) => OtherUserProfilePage(user: user),
              ),
            ),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _tabs.asMap().entries.map((entry) {
          final isSelected = entry.key == _selectedTab;
          final isLast = entry.key == _tabs.length - 1;
          final icon = _iconForTab(entry.key);

          return Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 10),
            child: GestureDetector(
              onTap: () {
                if (_selectedTab == entry.key) return;
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = entry.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: 40,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 16 : 11,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? PinitColors.aubergine
                      : PinitColors.creamSunk,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? PinitColors.aubergine
                        : PinitColors.creamDeep,
                    width: 1.5,
                  ),
                  boxShadow: isSelected ? PinitColors.subtleShadow : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: isSelected
                          ? PinitColors.cream
                          : PinitColors.aubergineSoft,
                    ),
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerLeft,
                        child: isSelected
                            ? Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontFamily: 'Rova',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w100,
                                    color: PinitColors.cream,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _iconForTab(int index) {
    switch (index) {
      case 0:
        return Icons.local_fire_department_rounded;
      case 1:
        return Icons.collections_bookmark_rounded;
      case 2:
        return Icons.people_alt_rounded;
      default:
        return Icons.circle;
    }
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: const BoxDecoration(
                      color: PinitColors.accent,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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

  Future<void> _openFollowers(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserListPage(
          title: 'Followers',
          loader: (s) => s.users.getFollowers(),
          emptyMessage: 'No followers yet',
        ),
      ),
    );
    _loadFollowCounts();
  }

  Future<void> _openFollowing(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserListPage(
          title: 'Following',
          loader: (s) => s.users.getFollowingList(),
          emptyMessage: "You are not following anyone yet",
        ),
      ),
    );
    _loadFollowCounts();
  }

  void _showNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsPopover(),
        fullscreenDialog: true,
      ),
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
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const EditProfilePage(),
            ),
          );
        },
        onPreferences: () {
          Navigator.pop(sheetContext);
          // Refuse to open Preferences until the user's vibe affinities have
          // actually loaded — otherwise the page would have no real data to
          // edit and any save would risk overwriting real values.
          final affinity = context.read<UserDataProvider>().vibeTagAffinity;
          if (affinity == null || affinity.isEmpty) {
            unawaited(
              AppFeedback.showError(
                context,
                title: 'Still loading',
                message: 'Loading your vibes — try again in a moment.',
              ),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PreferencesPage(),
            ),
          );
        },
        onShareProfile: () {
          Navigator.pop(sheetContext);
          _shareProfile(context);
        },
        onSignOut: () {
          Navigator.pop(sheetContext);
          _handleSignOut(context);
        },
      ),
    );
  }

  void _shareProfile(BuildContext context) {
    const appStoreUrl =
        'https://apps.apple.com/app/pinit'; // replace with real URL
    Share.share(
      "I've got Pinit and I want to be your friend! 🍽️ Join me on the app: $appStoreUrl",
      subject: 'Join me on Pinit!',
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
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.6,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Small changes here shape how people discover you on Pinit.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              const SizedBox(height: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PinitColors.aubergine,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: PinitColors.aubergineSoft,
                      height: 1.3,
                    ),
                  ),
                ],
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
            color:
                isDestructive ? const Color(0xFFFFF5F2) : PinitColors.creamSunk,
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
