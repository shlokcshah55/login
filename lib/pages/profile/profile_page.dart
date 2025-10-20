import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:login/models/users.dart';
import 'package:login/supabase/helpers/auth.dart';
import 'package:login/supabase/service.dart';
import 'package:provider/provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/pages/login_page.dart';
import 'package:login/widgets/profile/profile_stats_card.dart';
import 'package:login/widgets/profile/activity_insights_card.dart';
import 'package:login/widgets/profile/quick_actions_card.dart';
import 'package:login/widgets/profile/recent_pins_section.dart';
import 'package:login/widgets/profile/find_friends_section.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _PinitProfileScreenState createState() => _PinitProfileScreenState();
}

class _PinitProfileScreenState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final SupabaseService supabaseProvider = SupabaseService();
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationListManager>(context, listen: false)
          .fetchSavedLocations();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      final authService = AuthHelper();
      await authService.signOut();

      if (mounted) {
        Provider.of<UserDataProvider>(context, listen: false).clearUserData();
        Provider.of<LocationListManager>(context, listen: false).clearData();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
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

    if (userDataProvider.isLoading && user == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.6)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Please log in', style: theme.textTheme.titleLarge),
            ],
          ),
        ),
      );
    }

    final savedPins = locationListManager.savedLocations.keys.toList();
    final headerOpacity = (_scrollOffset / 150).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Custom App Bar with Image Background
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: theme.primaryColor,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.primaryColor,
                          theme.primaryColor.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Profile info overlay
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: 1 - headerOpacity,
                      child: Column(
                        children: [
                          Hero(
                            tag: 'profile_avatar',
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                                    ? NetworkImage(user.profileImageUrl!)
                                    : const AssetImage('lib/assets/default_avatar.png') as ImageProvider,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user.name ?? 'No Name',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {
                  _showSettingsMenu(context);
                },
              ),
            ],
          ),
          
          // Profile Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Stats Cards
                ProfileStatsCard(
                  user: user,
                  savedPinsCount: savedPins.length,
                  theme: theme,
                ),
                
                // Activity Insights
                ActivityInsightsCard(
                  savedPins: savedPins,
                  theme: theme,
                ),
                
                const SizedBox(height: 20),
                
                // Find Friends Section
                // FindFriendsSection(theme: theme),
                
                const SizedBox(height: 20),
                
                // Quick Actions
                QuickActionsCard(
                  theme: theme,
                  onEditProfile: () {
                    // Navigate to edit profile
                  },
                  onShareProfile: () {
                    // Share profile functionality
                  },
                ),
                
                // Recent Pins Preview
                RecentPinsSection(
                  savedPins: savedPins,
                  manager: locationListManager,
                  theme: theme,
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to edit profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleSignOut(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
