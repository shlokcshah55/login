import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:login/models/users.dart';
import 'package:login/models/locations.dart';
import 'package:login/supabase/service.dart';
import 'package:provider/provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'widgets/pinit_colors.dart';
import 'widgets/taste_match_card.dart';
import 'widgets/map_preview_card.dart';
import 'widgets/hidden_gems_section.dart';
import 'widgets/trending_now_section.dart';

class OtherUserProfilePage extends StatefulWidget {
  final UserModel user;

  const OtherUserProfilePage({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;
  int _selectedTab = 0;
  bool _isLoading = true;
  List<LocationModel> _userPins = [];
  String _followStatus = 'idle'; // idle, requested, accepted

  final List<String> _tabs = ['Pins', 'Map'];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadUserData();
  }

  void _onScroll() {
    setState(() => _scrollOffset = _scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final supabaseService =
          Provider.of<SupabaseService>(context, listen: false);

      // Get user's saved locations
      final locations = await supabaseService.locations
          .getUserSavedLocations(widget.user.supabaseId!);

      // Get follow status
      final status =
          await supabaseService.users.getFollowStatus(widget.user.supabaseId!);

      if (mounted) {
        setState(() {
          _userPins = locations;
          _followStatus = status ?? 'idle';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFollowAction() async {
    try {
      final supabaseService =
          Provider.of<SupabaseService>(context, listen: false);

      if (_followStatus == 'idle') {
        await supabaseService.users.followUser(widget.user.supabaseId!);
        if (mounted) setState(() => _followStatus = 'requested');
      } else if (_followStatus == 'requested' || _followStatus == 'accepted') {
        await supabaseService.users.unfollowUser(widget.user.supabaseId!);
        if (mounted) setState(() => _followStatus = 'idle');
      }
    } catch (e) {
      print('Error handling follow action: $e');
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final collapsedHeader = _scrollOffset > 120;
    final currentUser = Provider.of<UserDataProvider>(context).supabaseUserData;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: collapsedHeader
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PinitColors.background,
        body: _isLoading
            ? _buildLoadingState()
            : Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // Back button
                      SliverToBoxAdapter(
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      PinitColors.background.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: PinitColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Profile Header
                      SliverToBoxAdapter(
                        child: _buildProfileHeader(),
                      ),

                      // Taste Match Section
                      if (currentUser != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            child: TasteMatchCard(
                              overlapPercentage:
                                  72, // TODO: Calculate from actual data
                              sharedPlaces: _calculateSharedPlaces(currentUser),
                              sharedTastes: _calculateSharedTastes(),
                            ),
                          ),
                        ),

                      // Tab Bar
                      SliverAppBar(
                        pinned: true,
                        elevation: 0,
                        backgroundColor: PinitColors.background,
                        automaticallyImplyLeading: false,
                        toolbarHeight: 56,
                        flexibleSpace: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerLeft,
                          child: Row(
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

                      // Content
                      SliverToBoxAdapter(
                        child: _buildTabContent(),
                      ),

                      // Bottom padding
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ),

                  // Collapsed header overlay
                  if (collapsedHeader)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildCollapsedHeader(),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: PinitColors.warmGradient,
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        children: [
          // Profile Photo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: widget.user.profileImageUrl != null &&
                        widget.user.profileImageUrl!.isNotEmpty
                    ? NetworkImage(widget.user.profileImageUrl!)
                    : const AssetImage('lib/assets/default_avatar.png')
                        as ImageProvider,
                fit: BoxFit.cover,
              ),
              border: Border.all(
                color: Colors.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            widget.user.name ?? 'No Name',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: PinitColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Bio
          if (widget.user.bio != null && widget.user.bio!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.user.bio!,
                style: const TextStyle(
                  fontSize: 15,
                  color: PinitColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
              ),
            ),
          const SizedBox(height: 20),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat(_userPins.length.toString(), 'Pins'),
              const SizedBox(width: 32),
              _buildStat(widget.user.followersCount.toString(), 'Followers'),
              const SizedBox(width: 32),
              _buildStat(widget.user.followingCount.toString(), 'Following'),
            ],
          ),
          const SizedBox(height: 24),

          // Follow Button
          _buildFollowButton(),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return GestureDetector(
      onTap: () {
        // Navigate to followers/following list
      },
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
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

  Widget _buildFollowButton() {
    String buttonText;
    Color buttonColor;
    Color textColor;

    switch (_followStatus) {
      case 'idle':
        buttonText = 'Follow';
        buttonColor = PinitColors.primary;
        textColor = Colors.white;
        break;
      case 'requested':
        buttonText = 'Requested';
        buttonColor = PinitColors.surfaceLight;
        textColor = PinitColors.textSecondary;
        break;
      case 'accepted':
        buttonText = 'Following';
        buttonColor = PinitColors.surfaceLight;
        textColor = PinitColors.primary;
        break;
      default:
        buttonText = 'Follow';
        buttonColor = PinitColors.primary;
        textColor = Colors.white;
    }

    return GestureDetector(
      onTap: _handleFollowAction,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _followStatus == 'idle'
              ? [
                  BoxShadow(
                    color: PinitColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          buttonText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return Column(
          children: [
            if (_userPins.isNotEmpty) ...[
              HiddenGemsSection(
                savedPins: _userPins,
              ),
              TrendingNowSection(
                savedPins: _userPins,
              ),
            ] else
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 64,
                      color: PinitColors.textMuted.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No saved pins yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: PinitColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case 1:
        return _userPins.isNotEmpty
            ? MapPreviewCard(
                savedPins: _userPins,
                isFullView: true,
              )
            : Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 64,
                      color: PinitColors.textMuted.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No locations to display',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: PinitColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCollapsedHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: PinitColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: PinitColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 20,
                color: PinitColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: widget.user.profileImageUrl != null &&
                        widget.user.profileImageUrl!.isNotEmpty
                    ? NetworkImage(widget.user.profileImageUrl!)
                    : const AssetImage('lib/assets/default_avatar.png')
                        as ImageProvider,
                fit: BoxFit.cover,
              ),
              border: Border.all(
                color: PinitColors.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.user.name ?? 'Profile',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PinitColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
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
            'Loading profile...',
            style: TextStyle(
              fontSize: 16,
              color: PinitColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateSharedPlaces(UserModel currentUser) {
    // TODO: Implement actual calculation
    return 6;
  }

  List<String> _calculateSharedTastes() {
    // TODO: Implement actual calculation
    return ['Late-night veggie spots', 'East London'];
  }
}
