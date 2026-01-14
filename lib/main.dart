import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'package:login/widgets/wizard_completion_popover.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:login/services/fcm_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📲 Background message: ${message.notification?.title}');
  print('📲 Background message body: ${message.notification?.body}');
  print('📲 Background message data: ${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is already initialized in AppDelegate.swift for iOS
  // For Android, we still need to initialize it here
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');
  } catch (e) {
    // Firebase may already be initialized by native code (iOS)
    print('⚠️ Firebase initialization skipped (may already be initialized): $e');
  }

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permissions (non-blocking)
  FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  ).then((settings) {
    print('✅ Notification permissions: ${settings.authorizationStatus}');
  }).catchError((e) {
    print('❌ Error requesting notification permissions: $e');
  });

  // Permission request might be better handled within DeviceLocationProvider or on first use
  // await requestLocationPermission();
  print('🔧 Initializing custom marker...');
  await LocationModel.initializeCustomMarker();

  print('🔧 Loading .env file...');
  await dotenv.load();

  final googlePlacesService = GooglePlacesService();

  // Debug API key loading
  googlePlacesService.debugApiKey();

  // Initialize Supabase Provider (this handles SupabaseClientManager initialization)
  print('🔧 Initializing Supabase...');
  final supabaseProvider = SupabaseService();
  await supabaseProvider.initialize();

  print('✅ All initialization complete!');

  // Initialize FCM Service in background (non-blocking)
  // This prevents blocking app startup if token fetch is slow
  FCMService().initialize().catchError((e) {
    print('❌ Error initializing FCM: $e');
  });

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

    // Listen to auth state changes to save/clear user ID for share extension
    SupabaseClientManager().client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _saveUserIdToAppGroup();
      } else {
        _clearUserIdFromAppGroup();
      }
    });

    // Save user ID on app start if already logged in
    if (SupabaseClientManager().currentUser != null) {
      _saveUserIdToAppGroup();
    }

    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      setState(() {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);
        print("found shared files while app is open");
        print(_sharedFiles.map((f) => f.toMap()));

        // Note: TikTok sharing now handled by iOS share extension + backend
        // No need to process here
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

        // Note: TikTok sharing now handled by iOS share extension + backend
        // No need to process here

        // Tell the library that we are done processing the intent.
        ReceiveSharingIntent.instance.reset();
      });
    });
  }

  /// Save user ID to App Group UserDefaults for share extension access
  Future<void> _saveUserIdToAppGroup() async {
    try {
      final userId = SupabaseClientManager().currentUser?.id;
      if (userId == null) {
        print("⚠️ Cannot save user ID: No user logged in");
        return;
      }

      await platform.invokeMethod('saveUserId', {'userId': userId});
      print("✅ Saved user ID to App Group for share extension: $userId");
    } catch (e) {
      print("❌ Error saving user ID to App Group: $e");
    }
  }

  /// Clear user ID from App Group UserDefaults when user logs out
  Future<void> _clearUserIdFromAppGroup() async {
    try {
      await platform.invokeMethod('clearUserId');
      print("🗑️ Cleared user ID from App Group");
    } catch (e) {
      print("❌ Error clearing user ID from App Group: $e");
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
      theme: buildThemeData(),
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
  bool _hasShownWizardPopover = false;

  final List<Widget> _pages = [
    const HomePage(),
    BubblesPage(),
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
              onIndexChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
