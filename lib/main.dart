import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:login/pages/bubbles_page.dart';
import 'package:login/themes/app_theme.dart';
import 'package:login/models/locations.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/supabase/service.dart';
import 'package:login/pages/alerts_page.dart';
import 'package:login/pages/splash_screen.dart';
import 'package:login/pages/home_page.dart';
import 'package:login/pages/profile/profile_page.dart';
import 'package:login/pages/signup_wizard/wizard_completion_page.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:login/providers/nav_bar/dynamic_nav_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/widgets/navigation/bottom_nav_bar.dart';
import 'package:login/widgets/url_processing_popover.dart';
import 'package:login/widgets/wizard_completion_popover.dart';
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

  final googlePlacesService = GooglePlacesService();

  // Debug API key loading
  googlePlacesService.debugApiKey();

  // Initialize Supabase Provider
  final supabaseProvider = SupabaseService();
  await supabaseProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        // Supabase Provider
        ChangeNotifierProvider.value(value: supabaseProvider),

        ChangeNotifierProvider(create: (_) => UserDataProvider()),
        ChangeNotifierProvider(
            create: (_) => LocationListManager(googlePlacesService)),
        ChangeNotifierProvider(create: (_) => MapStateProvider()),

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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.example.srishlok.pinit/share');
  late StreamSubscription _intentSub;
  final _sharedFiles = <SharedMediaFile>[];
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer to detect when app resumes
    WidgetsBinding.instance.addObserver(this);

    // Setup listener for share extension deep link notifications
    platform.setMethodCallHandler(_handleNativeMethodCall);

    // Check for URLs from share extension on startup
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Check for shared URLs when app resumes from background
    if (state == AppLifecycleState.resumed) {
      _checkSharedURLs();
    }
  }

  /// Handle method calls from native iOS code
  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    print("📲 Flutter: Received method call from native: ${call.method}");

    if (call.method == 'onSharedData') {
      print("📲 Flutter: Share extension deep link detected - checking for shared URLs");
      await _checkSharedURLs();
    }

    return null;
  }

  /// Check for URLs shared from the share extension
  Future<void> _checkSharedURLs() async {
    try {
      final List<dynamic> urls = await platform.invokeMethod('getSharedURLs');
      if (urls.isNotEmpty) {
        print("📲 Found ${urls.length} shared URLs from extension: $urls");

        // Get the URL to process (only the first one)
        final urlToProcess = urls.first as String;

        // Clear URLs from storage immediately
        await platform.invokeMethod('clearSharedURLs');
        print("✅ Cleared shared URLs from storage");

        // Show popover with the URL
        _showSharePopover(urlToProcess);
      }
    } catch (e) {
      print("Error checking shared URLs: $e");
    }
  }

  /// Show popover overlay with shared content
  void _showSharePopover(String url) {
    print("📲 Showing popover for URL: $url");

    // Wait a bit to ensure the navigator is ready
    Future.delayed(Duration(milliseconds: 300), () {
      final context = navigatorKey.currentContext;
      if (context != null) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => UrlProcessingPopover(
            url: url,
            onProcess: (urlToProcess) async {
              // Process the URL and return location data
              return await _processTikTokURL(urlToProcess);
            },
            onDismiss: () async {
              // URLs already cleared immediately after reading
              // No need to clear again
            },
          ),
        );
      }
    });
  }



  /// Process a single TikTok URL
  Future<Map<String, dynamic>> _processTikTokURL(String url) async {
    print("🚀 START: Processing TikTok link: $url");

    try {
      print("🔍 Step 1: Getting current user ID...");
      // Get current user ID
      final userId = SupabaseClientManager().currentUser?.id;
      if (userId == null) {
        print("❌ Error: User not logged in. Cannot process TikTok links.");
        throw Exception("You must be logged in to process URLs");
      }

      print("✅ Step 2: User ID obtained: $userId");

      final apiUrl =
          'https://tiktok-processor-107523489868.europe-west1.run.app/process';

      print("📡 Step 3: Sending request to: $apiUrl");
      print("📤 Step 4: Request body: ${jsonEncode({'url': url, 'userId': userId})}");

      print("⏳ Step 5: Making HTTP POST request...");
      print("⏳ Step 5: Making HTTP POST request...");
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'url': url,
          'userId': userId,
        }),
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          print("⏱️ ERROR: Request timed out after 90 seconds");
          throw Exception("Request timed out - API took too long to respond");
        },
      );

      print("✅ Step 6: Response received!");
      print("📥 Step 7: Response status: ${response.statusCode}");
      print("📥 Step 8: Response body length: ${response.body.length} chars");
      print("📥 Step 9: Response body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...");

      if (response.statusCode == 200) {
        print("✅ Step 10: Status 200 - Parsing JSON response...");
        final responseData = jsonDecode(response.body);

        print("✅ Step 11: JSON parsed successfully");
        print("📊 Step 12: Response success field: ${responseData['success']}");

        if (responseData['success'] == true) {
          print("✅ Step 13: Processing successful response...");
          final locationsRaw = responseData['locations'] as List;

          print("✅ Step 14: Found ${locationsRaw.length} location(s) in response");

          // Parse each location and convert to a structured format
          print("🔄 Step 15: Parsing ${locationsRaw.length} locations...");
          final parsedLocations = locationsRaw.map((loc) {
            final placeData = loc['place'] as Map<String, dynamic>;
            final videoData = loc['video_data'] as Map<String, dynamic>;

            // Convert to LocationModel for consistency
            final locationModel = _googlePlaceToLocationModel(placeData);

            return {
              'location': locationModel,
              'place': placeData,
              'video_data': videoData,
            };
          }).toList();

          print("✅ Step 16: Successfully extracted ${parsedLocations.length} location(s)");
          print("🎉 COMPLETE: Returning success result");

          return {
            'success': true,
            'locations': parsedLocations,
            'url': url,
          };
        } else {
          final error = responseData['error'] ?? 'Unknown error';
          print("❌ Step 13-ERROR: TikTok processing returned error: $error");
          throw Exception("Could not extract location: $error");
        }
      } else {
        print("❌ Step 10-ERROR: Failed - Status: ${response.statusCode}");
        print("❌ Response body: ${response.body}");
        throw Exception("Failed to process URL: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      print("❌❌❌ EXCEPTION CAUGHT in _processTikTokURL ❌❌❌");
      print("❌ Error type: ${e.runtimeType}");
      print("❌ Error message: $e");
      print("❌ Stack trace: $stackTrace");
      // Re-throw to let the popover handle it
      rethrow;
    }
  }

  /// Convert Google Places API response to LocationModel
  LocationModel _googlePlaceToLocationModel(Map<String, dynamic> placeData) {
    final placeId = placeData['place_id'] as String;
    final location = placeData['location'] as Map<String, dynamic>;

    return LocationModel(
      locationId: placeId.hashCode.abs(), // Stable int ID from place_id
      name: placeData['name'] as String,
      vicinity: placeData['address'] as String? ?? '',
      lat: (location['lat'] as num).toDouble(),
      lng: (location['lng'] as num).toDouble(),
      createdAt: DateTime.now(),
      rating: (placeData['rating'] as num?)?.toDouble(),
      photoReference: placeData['photo_reference'] as String?,
      priceLevel: placeData['price_level'] as int?,
    );
  }

  /// Process received shared links from social media and publish them to Pub/Sub
  Future<void> addFilesToProcess(List<SharedMediaFile> sharedFiles) async {
    print("Background Task Service: Processing shared files");
    List<String> urls = sharedFiles.map((f) => f.path).toList();
    print("These are the urls, $urls");

    for (String url in urls) {
      if (url.contains("tiktok.com")) {
        try {
          final result = await _processTikTokURL(url);
          print("Processing result: $result");
        } catch (e) {
          print("Error processing URL: $e");
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Pinit',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      home: const SplashScreenActual(),
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
  bool _hasUnreadNotifications = false;
  bool _hasShownWizardPopover = false;

  final List<Widget> _pages = [
    const HomePage(),
    BubblesPage(),
    const AlertsPage(),
    ProfilePage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Show wizard completion popover once per session if wizard incomplete
    if (!_hasShownWizardPopover) {
      _checkAndShowWizardPopover();
    }
  }

  Future<void> _checkAndShowWizardPopover() async {
    _hasShownWizardPopover = true;

    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final wizardCompleted = userDataProvider.supabaseUserData?.wizardCompleted ?? false;

    if (!wizardCompleted) {
      // Delay to ensure screen is built and give user time to see the app
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        _showWizardCompletionPopover();
      }
    }
  }

  void _showWizardCompletionPopover() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Complete Profile',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 800),
      pageBuilder: (context, animation, secondaryAnimation) {
        return WizardCompletionPopover(
          onComplete: () {
            Navigator.pop(context);
            _navigateToWizardCompletion();
          },
          onDismiss: () => Navigator.pop(context),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Scale animation with overshoot (0.0 → 1.1 → 1.0)
        final scaleAnimation = TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween(begin: 0.0, end: 1.1)
                .chain(CurveTween(curve: Curves.easeOutBack)),
            weight: 70.0,
          ),
          TweenSequenceItem(
            tween: Tween(begin: 1.1, end: 1.0)
                .chain(CurveTween(curve: Curves.easeInOut)),
            weight: 30.0,
          ),
        ]).animate(animation);

        // Fade in (0.0 → 1.0)
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ),
        );

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
    );
  }

  void _navigateToWizardCompletion() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WizardCompletionPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _pages[_currentIndex],

          // Positioned BottomNavBar
          Positioned(
            left: 12,
            right: 12,
            bottom: 24,
            child: BottomNavBar(
              currentIndex: _currentIndex,
              hasUnreadNotifications: _hasUnreadNotifications,
              onIndexChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  if (index == 2 && _hasUnreadNotifications) {
                    _hasUnreadNotifications = false;
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
