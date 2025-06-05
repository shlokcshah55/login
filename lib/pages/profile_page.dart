import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/location_list_manager.dart';
import 'package:login/supabase_flutter/models/user_model.dart';
import 'package:login/supabase_flutter/models/location_model.dart';
import 'package:login/widgets/profile/location_card.dart';
import 'package:login/widgets/profile/user_card.dart';
import 'package:login/supabase_flutter/repositories/user_repository.dart';
import 'package:login/themes/app_colors.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/themes/app_dimensions.dart';
import 'package:login/pages/settings_page.dart';
import 'package:login/pages/edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _PinitProfileScreenState createState() => _PinitProfileScreenState();
}

class _PinitProfileScreenState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserModel> _suggestedUsers = [];
  bool _isLoadingSuggestions = false;
  final UserRepository _userRepository = UserRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Tabs for "Friends", "Pins", "Maps"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationListManager>(context, listen: false)
          .fetchSavedLocations();
      _fetchSuggestedUsers();
    });
  }

  Future<void> _fetchSuggestedUsers() async {
    setState(() {
      _isLoadingSuggestions = true;
    });
    try {
      final users = await _userRepository.getSuggestedUsers();
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _suggestedUsers = users;
        });
      }
    } catch (e) {
      // Handle error appropriately, maybe show a snackbar
      print("Error fetching suggested users: $e");
      if (mounted) {
         // Optionally show an error message to the user
      }
    }
    if (mounted) {
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context);
    final locationListManager = Provider.of<LocationListManager>(context);
    final UserModel? user = userDataProvider.supabaseUserData;

    if (userDataProvider.isLoading && user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 64,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: AppSpacing.medium),
              Text(
                'User data not available',
                style: AppTypography.headingMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppSpacing.small),
              Text(
                'Please log in to view your profile',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final savedPins = locationListManager.savedLocations.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(user),
          SliverToBoxAdapter(
            child: _buildProfileContent(user, savedPins, locationListManager),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(UserModel user) {
    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.settings_outlined, color: AppColors.onPrimary),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsPage(),
              ),
            );
          },
        ),
        SizedBox(width: AppSpacing.small),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
                AppColors.background,
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: AppSpacing.xl),
                _buildProfileImage(user),
                SizedBox(height: AppSpacing.medium),
                Text(
                  user.name ?? 'No Name',
                  style: AppTypography.headingLarge.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  user.email,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onPrimary.withOpacity(0.8),
                  ),
                ),
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.small),
                  Padding(
                    padding: AppSpacing.paddingHorizontalLarge,
                    child: Text(
                      user.bio!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onPrimary.withOpacity(0.9),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(UserModel user) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 45,
        backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
            ? NetworkImage(user.profileImageUrl!)
            : null,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
            ? Icon(
                Icons.person,
                size: 40,
                color: AppColors.primary,
              )
            : null,
      ),
    );
  }

  Widget _buildProfileContent(UserModel user, List<LocationModel> savedPins, LocationListManager manager) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsSection(user, savedPins.length),
        SizedBox(height: AppSpacing.large),
        _buildActionButtons(),
        SizedBox(height: AppSpacing.large),
        _buildTabSection(savedPins, manager),
      ],
    );
  }

  Widget _buildStatsSection(UserModel user, int savedPinsCount) {
    return Container(
      margin: AppSpacing.paddingHorizontalMedium,
      padding: AppSpacing.paddingLarge,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusLarge,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Followers', user.followersCount.toString()),
          _buildVerticalDivider(),
          _buildStatItem('Following', user.followingCount.toString()),
          _buildVerticalDivider(),
          _buildStatItem('Saved Pins', savedPinsCount.toString()),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.headingMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: AppColors.divider,
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: AppSpacing.paddingHorizontalMedium,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(Icons.edit_outlined, size: 18),
              label: Text('Edit Profile'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EditProfilePage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: AppSpacing.paddingVerticalMedium,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusMedium,
                ),
                elevation: AppElevation.small,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.medium),
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(Icons.share_outlined, size: 18),
              label: Text('Share Profile'),
              onPressed: () {
                // Share profile
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary, width: 1.5),
                padding: AppSpacing.paddingVerticalMedium,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection(List<LocationModel> savedPins, LocationListManager manager) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            margin: AppSpacing.paddingHorizontalMedium,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.radiusMedium,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: AppTypography.labelMedium,
              unselectedLabelStyle: AppTypography.bodyMedium,
              tabs: const [
                Tab(text: 'Friends'),
                Tab(text: 'Pins'),
                Tab(text: 'Maps'),
              ],
            ),
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildModernFriendsTab(),
                _buildModernPinsGrid(savedPins, manager),
                _buildModernMapsGrid(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFriendsTab() {
    if (_isLoadingSuggestions) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      );
    }
    
    if (_suggestedUsers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'No suggested users',
        subtitle: 'Check back later for new suggestions!',
      );
    }
    
    return Container(
      padding: AppSpacing.paddingMedium,
      child: ListView.builder(
        itemCount: _suggestedUsers.length,
        itemBuilder: (context, index) {
          final user = _suggestedUsers[index];
          return Container(
            margin: AppSpacing.paddingVerticalSmall,
            child: UserCard(user: user),
          );
        },
      ),
    );
  }

  Widget _buildModernPinsGrid(List<LocationModel> pins, LocationListManager manager) {
    if (pins.isEmpty) {
      return _buildEmptyState(
        icon: Icons.location_on_outlined,
        title: 'No saved pins yet',
        subtitle: 'Explore and save some amazing places!',
      );
    }

    return Container(
      padding: AppSpacing.paddingMedium,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 0.85,
        ),
        itemCount: pins.length,
        itemBuilder: (context, index) {
          final pin = pins[index];
          return LocationCard(
            location: pin,
            isInitiallySaved: true,
            onSaveToggle: (isSaved) {
              if (!isSaved) {
                manager.removeLocation(pin);
              } else {
                manager.saveLocation(pin);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildModernMapsGrid() {
    return _buildEmptyState(
      icon: Icons.map_outlined,
      title: 'No maps created yet',
      subtitle: 'Your created maps and custom pins will appear here.',
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: AppSpacing.paddingLarge,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: AppSpacing.paddingLarge,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: AppSpacing.medium),
          Text(
            title,
            style: AppTypography.headingSmall.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.small),
          Text(
            subtitle,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Helper class for SliverPersistentHeader to make TabBar sticky
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface, 
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false; // TabBar itself doesn\'t change, so no need to rebuild
  }
}