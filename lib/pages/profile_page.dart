import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/location_list_manager.dart';
import 'package:login/supabase_flutter/models/user_model.dart';
import 'package:login/supabase_flutter/models/location_model.dart';
import 'package:login/themes/app_colors.dart'; // Import AppColors
import 'package:login/widgets/profile/location_card.dart'; // Assuming you have a LocationCard widget
import 'package:login/widgets/profile/user_card.dart';
import 'package:login/supabase_flutter/repositories/user_repository.dart';
import 'package:login/supabase_flutter/services/supabase_auth_service.dart';
import 'package:login/pages/login_page.dart';

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

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      final authService = SupabaseAuthService();
      await authService.signOut();

      // Clear providers if needed
      if (mounted) {
        Provider.of<UserDataProvider>(context, listen: false).clearUserData();
        Provider.of<LocationListManager>(context, listen: false).clearData();

        // Navigate to login page and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDataProvider = Provider.of<UserDataProvider>(context);
    final locationListManager = Provider.of<LocationListManager>(context);
    final UserModel? user = userDataProvider.supabaseUserData;
    final theme = Theme.of(context);

    if (userDataProvider.isLoading && user == null) { // Show loading only if user data is not yet available
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Text(
            'User data not available. Please log in.',
            style: theme.textTheme.titleMedium,
          ),
        ),
      );
    }

    final savedPins = locationListManager.savedLocations.keys.toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('Profile', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onPrimary)),
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.colorScheme.onPrimary),
            onSelected: (value) {
              if (value == 'settings') {
                // Navigate to settings page or show settings dialog
              } else if (value == 'logout') {
                _handleSignOut(context);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 8),
                      Text('Settings'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 8),
                      Text('Sign Out'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return <Widget>[
            SliverToBoxAdapter(
              child: _buildProfileHeader(context, user, savedPins.length),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorColor: theme.colorScheme.primary,
                  tabs: const [
                    Tab(text: 'Friends'), 
                    Tab(text: 'Pins'),
                    Tab(text: 'Maps'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildFriendsTab(context),
            _buildPinsGrid(context, savedPins, locationListManager),
            _buildMapsGrid(context), 
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel user, int savedPinsCount) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: <Widget>[
          CircleAvatar(
            radius: 50,
            backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                ? NetworkImage(user.profileImageUrl!)
                : const AssetImage('lib/assets/default_avatar.png') as ImageProvider,
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(height: 15),
          Text(
            user.name ?? 'No Name',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 5),
          Text(
            user.email, 
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (user.bio != null && user.bio!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                user.bio!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildStatItem(context, 'Followers', user.followersCount.toString()),
              _buildStatItem(context, 'Following', user.followingCount.toString()),
              _buildStatItem(context, 'Saved Pins', savedPinsCount.toString()),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.edit, size: 18),
            label: const Text('Edit Profile'),
            onPressed: () {
              // Navigate to an edit profile page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildFriendsTab(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoadingSuggestions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_suggestedUsers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'No suggested users at the moment. Check back later!',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return SizedBox(
      height: 220, // Adjust height to fit the smaller UserCard + padding
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        itemCount: _suggestedUsers.length,
        itemBuilder: (context, index) {
          final user = _suggestedUsers[index];
          return SizedBox(
            width: 180, // Adjust width for a smaller card
            child: UserCard(user: user), 
          );
        },
      ),
    );
  }

  Widget _buildPinsGrid(BuildContext context, List<LocationModel> pins, LocationListManager manager) {
    final theme = Theme.of(context);
    if (pins.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'No saved pins yet. Explore and save some amazing places!',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
        childAspectRatio: 0.8, 
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
              // This case should ideally not happen if it's already saved and shown here
              // but as a fallback, ensure it's saved.
              manager.saveLocation(pin); 
            }
          },
        );
      },
    );
  }

  Widget _buildMapsGrid(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          'Your created maps and pins will appear here.', // Updated text
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
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