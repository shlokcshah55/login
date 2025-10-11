import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:http/http.dart' as http;
import 'package:login/themes/app_theme.dart';
import 'package:login/supabase_flutter/models/location_model.dart';
import 'package:login/supabase_flutter/supabase_client.dart';
import 'package:login/supabase_flutter/supabase_provider.dart';
import 'package:login/pages/alerts_page.dart';
import 'package:login/pages/splash_screen.dart';
import 'package:login/pages/home_page.dart';
import 'package:login/pages/profile_page.dart';
import 'package:login/providers/device_location_provider.dart'; // Import new providers
import 'package:login/providers/location_list_manager.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/bottom_nav_visibility_provider.dart';
import 'package:login/providers/dynamic_nav_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/services/location_service.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Permission request might be better handled within DeviceLocationProvider or on first use
  // await requestLocationPermission();
  await LocationModel.initializeCustomMarker();
  await dotenv.load();

  // Initialize Supabase
  await SupabaseClientManager.initialize();

  // await NotificationService().initialize();
  // await BackgroundTaskService().initialize();

  // Instantiate services
  final googlePlacesService = GooglePlacesService();
  final locationService = LocationService();

  // Debug API key loading
  googlePlacesService.debugApiKey();

  // Initialize Supabase Provider
  final supabaseProvider = SupabaseProvider();
  await supabaseProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        // Supabase Provider
        ChangeNotifierProvider.value(value: supabaseProvider),

        // Legacy Firebase providers for gradual migration
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
        ChangeNotifierProvider(
            create: (_) => LocationListManager(googlePlacesService)),
        ChangeNotifierProvider(create: (_) => MapStateProvider()),
        ChangeNotifierProvider(
            create: (_) => DeviceLocationProvider(locationService)),
        
        // Bottom Navigation Visibility Provider
        ChangeNotifierProvider(create: (_) => BottomNavVisibilityProvider()),

        // Dynamic Navigation Provider
        ChangeNotifierProvider(create: (_) => DynamicNavProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('com.example.srishlok.pinit/share');
  late StreamSubscription _intentSub;
  final _sharedFiles = <SharedMediaFile>[];

  @override
  void initState() {
    super.initState();

    // Check for URLs from share extension
    _checkSharedURLs();

    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      setState(() {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);
        print("found shared files while app is open");
        print(_sharedFiles.map((f) => f.toMap()));

        // Process files when app is open
        if (_sharedFiles.isNotEmpty) {
          addFilesToProcess(_sharedFiles);
        }
      });
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      setState(() {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);

        print("found shared files when app was closed: ${_sharedFiles.length}");
        print("files: ${_sharedFiles.map((f) => (
              f.message,
              f.mimeType,
              f.path
            ))}");

        addFilesToProcess(_sharedFiles);

        // Tell the library that we are done processing the intent.
        ReceiveSharingIntent.instance.reset();
      });
    });
  }

  /// Check for URLs shared from the share extension
  Future<void> _checkSharedURLs() async {
    try {
      final List<dynamic> urls = await platform.invokeMethod('getSharedURLs');
      if (urls.isNotEmpty) {
        print("📲 Found ${urls.length} shared URLs from extension: $urls");

        // Process each URL
        for (String url in urls.cast<String>()) {
          if (url.contains("tiktok.com")) {
            await _processTikTokURL(url);
          }
        }

        // Clear the URLs after processing
        await platform.invokeMethod('clearSharedURLs');
      }
    } catch (e) {
      print("Error checking shared URLs: $e");
    }
  }

  /// Process a single TikTok URL
  Future<void> _processTikTokURL(String url) async {
    print("Background Task Service: Processing TikTok link: $url");

    // Get current user ID
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) {
      log("Error: User not logged in. Cannot process TikTok links.");
      return;
    }

    // Cloud Run API endpoint for publishing to Pub/Sub
    final apiUrl =
        'https://tiktok-producer-711637650309.europe-west2.run.app/v1/publish';

    try {
      // Send request to Cloud Run service, which will publish to PubSub
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'url': url,
          'userId': userId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        print("Sent tiktok to pubsub");
        log("TikTok link sent to Cloud Run API successfully: $url");
      } else {
        log("Failed to send TikTok link to Cloud Run API: ${response.body}");
      }
    } catch (e) {
      log("Error sending TikTok link to Cloud Run API: $e");
    }
  }

  /// Process received shared links from social media and publish them to Pub/Sub
  Future<void> addFilesToProcess(List<SharedMediaFile> sharedFiles) async {
    print("Background Task Service: Processing shared files");
    List<String> urls = sharedFiles.map((f) => f.path).toList();
    print("These are the urls, $urls");

    for (String url in urls) {
      if (url.contains("tiktok.com")) {
        await _processTikTokURL(url);
      }
    }
  }

  @override
  void dispose() {
    _intentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinit',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      home: const SplashScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _hasUnreadNotifications = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final List<Widget> _pages = [
    const HomePage(),
    const Center(child: Text('Search')),
    const AlertsPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _checkForPendingNotifications();
    
    // Initialize animation controller for bottom nav
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Slide animation from bottom
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Start below screen
      end: Offset.zero,         // End at normal position
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Start with visible bottom nav
    _animationController.forward();
  }

  Future<void> _checkForPendingNotifications() async {
    final locationManager =
        Provider.of<LocationListManager>(context, listen: false);
    final locations = await locationManager.getSavedLocationsSinceLastOpened();

    setState(() {
      _hasUnreadNotifications = locations.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BottomNavVisibilityProvider, DynamicNavProvider>(
      builder: (context, bottomNavProvider, dynamicNavProvider, child) {
        // Update animation based on visibility state
        if (bottomNavProvider.isVisible) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
        
        return Scaffold(
          body: _pages[_currentIndex],
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 68,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withBlue(10),
                      blurRadius: bottomNavProvider.isVisible ? 15 : 5,
                      spreadRadius: 0,
                      offset: Offset(0, bottomNavProvider.isVisible ? 6 : 2),
                    ),
                  ],
                ),
                child: dynamicNavProvider.navState == NavState.standard
                    ? _buildStandardNav()
                    : _buildDynamicNav(dynamicNavProvider),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStandardNav() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavItem(FeatherIcons.home, 0, 'Home'),
        _buildNavItem(FeatherIcons.search, 1, 'Search'),
        _buildNavItem(
            _hasUnreadNotifications
                ? FeatherIcons.bell
                : FeatherIcons.bell,
            2,
            'Alerts',
            hasBadge: _hasUnreadNotifications),
        _buildNavItem(FeatherIcons.user, 3, 'Profile'),
      ],
    );
  }

  Widget _buildDynamicNav(DynamicNavProvider dynamicNavProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.apps),
          onPressed: () {
            dynamicNavProvider.showStandardNav();
          },
        ),
        ElevatedButton(
          child: const Text('Explore'),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => ExpandedLocationCard(
                location: dynamicNavProvider.selectedLocation!,
                onClose: () => Navigator.of(context).pop(),
              ),
            );
          },
        ),
      ],
    );
  }

  // Improved nav item widget with animations and tooltip
  Widget _buildNavItem(IconData icon, int index, String label,
      {bool hasBadge = false}) {
    bool isSelected = _currentIndex == index;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () {
          context.read<BottomNavVisibilityProvider>().show();
          context.read<DynamicNavProvider>().showStandardNav();
          setState(() {
            _currentIndex = index;
            // Clear badge when navigating to the notifications page
            if (index == 2 && hasBadge) {
              _hasUnreadNotifications = false;
            }
          });
        },
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 16 : 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade600,
                    size: 26,
                  ),
                  if (hasBadge)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                  child: Text(label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
