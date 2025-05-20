import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:login/assets/constants.dart';
import 'package:login/supabase_flutter/models/location_model.dart';
import 'package:login/supabase_flutter/supabase_client.dart';
import 'package:login/supabase_flutter/supabase_provider.dart';
import 'package:login/notifications/notificationService.dart';
import 'package:login/notifications/backgroundTaskService.dart';
import 'package:login/pages/auth_handler.dart';
import 'package:login/pages/home_page.dart';
import 'package:login/pages/profile_page.dart';
import 'package:login/providers/device_location_provider.dart'; // Import new providers
import 'package:login/providers/location_list_manager.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/services/location_service.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Permission request might be better handled within DeviceLocationProvider or on first use
  // await requestLocationPermission();
  await LocationModel.initializeCustomMarker();
  await dotenv.load();

  // Initialize Firebase

  // Initialize Supabase
  await SupabaseClientManager.initialize();

  //TODO: Uncomment when migrating the notification service to Supabase

  // await NotificationService().initialize();
  // await BackgroundTaskService().initialize();

  // Instantiate services
  final googlePlacesService = GooglePlacesService();
  final locationService = LocationService();

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
  String? _sharedLink;
  late StreamSubscription _intentSub;
  final _sharedFiles = <SharedMediaFile>[];

  @override
  void initState() {
    super.initState();
    print("main init state");
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

  /// Process received shared links from social media and publish them to Pub/Sub
  Future<void> addFilesToProcess(List<SharedMediaFile> sharedFiles) async {
    print("Background Task Service: Processing shared files");
    List<String> urls = sharedFiles.map((f) => f.path).toList();
    print("These are the urls, $urls");
    // Get current user ID
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) {
      log("Error: User not logged in. Cannot process TikTok links.");
      return;
    }

    // Cloud Run API endpoint for publishing to Pub/Sub
    final apiUrl =
        'https://process-tiktok-711637650309.europe-west1.run.app/v1/publish';

    for (String url in urls) {
      if (url.contains("tiktok.com")) {
        log("Background Task Service: Processing TikTok link: $url");

        try {
          log('get into here');
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
      home: const AuthHandler(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const Center(child: Text('Search')),
    const Center(child: Text('Notifications')),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 68,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withBlue(10),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(Icons.home_rounded, 0, 'Home'),
            _buildNavItem(Icons.search_rounded, 1, 'Search'),
            _buildNavItem(Icons.notifications_rounded, 2, 'Alerts'),
            _buildNavItem(Icons.person_rounded, 3, 'Profile'),
          ],
        ),
      ),
      );
    }

      // Improved nav item widget with animations and tooltip
      Widget _buildNavItem(IconData icon, int index, String label) {
      bool isSelected = _currentIndex == index;

      return Tooltip(
        message: label,
        child: InkWell(
          onTap: () => setState(() {
            _currentIndex = index;
          }),
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 16 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey.shade600,
                  size: 26,
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
}
