import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:login/assets/constants.dart';
import 'package:login/firebase_options.dart';
import 'package:login/models/location_model.dart';
import 'package:login/notifications/notificationService.dart';
import 'package:login/notifications/backgroundTaskService.dart';
import 'package:login/pages/auth_handler.dart';
import 'package:login/pages/home_page.dart';
import 'package:login/pages/profile_page.dart';
// import 'package:login/providers/app_data_provider.dart'; // Remove old provider
import 'package:login/providers/device_location_provider.dart'; // Import new providers
import 'package:login/providers/location_list_manager.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/firebase_service.dart'; // Import services
import 'package:login/services/google_place_service.dart';
import 'package:login/services/location_service.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:login/permissions/permissions.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Permission request might be better handled within DeviceLocationProvider or on first use
  // await requestLocationPermission();
  await LocationModel.initializeCustomMarker();
  await dotenv.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initialize();
  await BackgroundTaskService().initialize();

  // Instantiate services
  final firebaseService = FirebaseService();
  final googlePlacesService = GooglePlacesService();
  final locationService = LocationService();

  runApp(
    MultiProvider(
      providers: [
        // Provide the services themselves if needed directly by widgets (less common)
        // Provider.value(value: firebaseService),
        // Provider.value(value: googlePlacesService),
        // Provider.value(value: locationService),

        // Provide the new ChangeNotifiers, injecting services
        ChangeNotifierProvider(
            create: (_) => UserDataProvider(firebaseService)),
        ChangeNotifierProvider(
            create: (_) =>
                LocationListManager(firebaseService, googlePlacesService)),
        ChangeNotifierProvider(
            create: (_) =>
                MapStateProvider()), // No service dependencies currently
        ChangeNotifierProvider(
            create: (_) => DeviceLocationProvider(locationService)),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
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
    log("main init state");

    // Listen to media sharing coming from outside the app while the app is in the memory.
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      setState(() {
        _sharedFiles.clear();
        _sharedFiles.addAll(value);
        print("found shared files 1");
        print(_sharedFiles.map((f) => f.toMap()));
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

  // Future<void> addFilesToProcess(List<SharedMediaFile> sharedFiles) async {

  //   print("Background Task Service: Processing shared files");
  //   List<String> urls = sharedFiles.map((f) => f.path).toList();
  //   FirebaseFirestore db = FirebaseFirestore.instance;

  //   for (String url in urls) {
  //     if (url.contains("tiktok.com")) {
  //       print("Background Task Service: Processing TikTok link: $url");
  //       await db.collection('incoming_tiktok_links').add({
  //         'url': url,
  //         'timestamp': FieldValue.serverTimestamp(),
  //       });
  //       print("TikTok link stored successfully: $url");
  //     }
  //   }

  // }

  Future<void> addFilesToProcess(List<SharedMediaFile> sharedFiles) async {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ??
        'unknown_user'; // Fallback to 'unknown_user' if no user is logged in

    print("Background Task Service: Processing shared files");
    List<String> urls = sharedFiles.map((f) => f.path).toList();

    // Get current user ID
    final firebaseService = FirebaseService();
    final userId = firebaseService.auth_.currentUser?.uid;
    if (userId == null) {
      log("Error: User not logged in. Cannot process TikTok links.");
      return;
    }

    // Cloud Run API endpoint for publishing to Pub/Sub
    final apiUrl = 'https://process-tiktok-711637650309.europe-west1.run.app';

    for (String url in urls) {
      if (url.contains("tiktok.com")) {
        log("Background Task Service: Processing TikTok link: $url");

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

  // Future<void> addFilesToProcess(List<SharedMediaFile> sharedFiles) async {
  //   print("Background Task Service: Processing shared files");
  //   List<String> urls = sharedFiles.map((f) => f.path).toList();

  //   // Get current user ID
  //   final firebaseService = FirebaseService();
  //   final userId = firebaseService.auth_.currentUser?.uid;
  //   if (userId == null) {
  //     log("Error: User not logged in. Cannot process TikTok links.");
  //     return;
  //   }

  //   // API endpoint for our service
  //   //final apiUrl = '${dotenv.env['API_BASE_URL'] ?? 'http://localhost:8080'}/v1/process-tiktok';
  //   final apiUrl = 'https://tiktok-api-711637650309.europe-west1.run.app';
  //   for (String url in urls) {
  //     if (url.contains("tiktok.com")) {
  //       log("Background Task Service: Processing TikTok link: $url");

  //       try {
  //         // Send request to API service, which will publish to PubSub
  //         final response = await http.post(
  //           Uri.parse(apiUrl),
  //           headers: <String, String>{
  //             'Content-Type': 'application/json',
  //           },
  //           body: jsonEncode(<String, String>{
  //             'url': url,
  //             'userId': userId,
  //           }),
  //         );

  //         if (response.statusCode == 200 || response.statusCode == 202) {
  //           log("TikTok link sent to API successfully: $url");
  //         } else {
  //           log("Failed to send TikTok link to API: ${response.body}");
  //         }
  //       } catch (e) {
  //         log("Error sending TikTok link to API: $e");
  //       }
  //     }
  //   }
  // }

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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).bottomAppBarTheme.color,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        // Items now use theme colors defined in bottomNavigationBarTheme
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home, color: Colors.black), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.search, color: Colors.black), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications, color: Colors.black), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.person, color: Colors.black), label: ''),
          BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: ''), // Label is optional, theme handles color
          BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
      ),
    );
  }
}
