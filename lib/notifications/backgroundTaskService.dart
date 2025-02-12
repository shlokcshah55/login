import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:login/models/location_model.dart';
import 'package:workmanager/workmanager.dart';
import 'package:login/notifications/notificationService.dart';
import 'package:login/services/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundTaskService {
  static final BackgroundTaskService _instance = BackgroundTaskService._internal();
  static final FirebaseService _firebaseService = FirebaseService();

  factory BackgroundTaskService() {
    return _instance;
  }

  BackgroundTaskService._internal();

  /// Initialize Workmanager for background tasks
  Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Set to false in production
    );

    // Register location checker task
    await Workmanager().registerPeriodicTask(
      'LocationChecker',
      'LocationChecker',
      frequency: const Duration(minutes: 15),
    );

    // Register TikTok processing task
    await Workmanager().registerOneOffTask(
      'ProcessTikTokShare',
      'ProcessTikTokShare',
    );
  }

  @pragma('vm:entry-point') 
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      try {
        switch (task) {
          case 'LocationChecker':
            await _handleLocationTask();
            break;
          case 'ProcessTikTokShare':
            await _handleTikTokProcessing();
            break;
          default:
            print('Background Task service: Unknown task: $task');
        }
      } catch (e) {
        print('Error in background task: $e');
        return Future.value(false);
      }
      return Future.value(true);
    });
  }

  /// Processes location-based notifications
  static Future<void> _handleLocationTask() async {
    Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    LocationData currentLocation = await location.getLocation();
    Map<LocationModel, Timestamp> locations = await _firebaseService.getSavedLocationsMap();

    for (var pair in locations.entries) {
      if (pair.key.isWithinRadius(1, currentLocation.latitude ?? 0, currentLocation.longitude ?? 0) &&
          pair.value.toDate().isBefore(DateTime.now().subtract(const Duration(hours: 24)))) {
        String name = pair.key.name;
        await NotificationService().showNotification(
          title: 'Hungry? You are so close to $name',
          body: 'You pinned this place recently, Check it out.',
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        _firebaseService.updateUserLocationTimestamp(pair.key.id);
      }
    }
  }

  /// Processes TikTok links and stores them in Firestore
  /// user shares tiktok link -> app recieves tiktok 
  /// mainActivity.kt captures it and saves in shared preferences
  /// flutter can then read it and create a task
  /// add to firestore which triggers a firebase function to handle processing on server
  static Future<void> _handleTikTokProcessing() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? sharedUrl = prefs.getString('flutter.shared_url');
    print("Background service: Saved link: ${prefs.getString('flutter.shared_url')}");

    if (sharedUrl != null && sharedUrl.isNotEmpty) {
      FirebaseFirestore db = FirebaseFirestore.instance;

      // Create a new document in Firestore with the shared URL
      await db.collection('incoming_tiktok_links').add({
        'url': sharedUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Clear the shared URL after processing
      await prefs.remove('flutter.shared_url');

      print("TikTok link stored successfully: $sharedUrl");
    }
  }
}
