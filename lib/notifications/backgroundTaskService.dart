import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:login/supabase_flutter/models/location_model.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:workmanager/workmanager.dart';
import 'package:login/notifications/notificationService.dart';
import 'package:login/services/firebase_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case 'LocationChecker':
          await BackgroundTaskService._handleLocationTask();
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

class BackgroundTaskService {
  static final BackgroundTaskService _instance =
      BackgroundTaskService._internal();
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
    Map<LocationModel, Timestamp> locations =
        await _firebaseService.getSavedLocationsMap();

    for (var pair in locations.entries) {
      if (pair.key.isWithinRadius(1, currentLocation.latitude ?? 0,
              currentLocation.longitude ?? 0) &&
          pair.value
              .toDate()
              .isBefore(DateTime.now().subtract(const Duration(hours: 24)))) {
        String name = pair.key.name;
        await NotificationService().showNotification(
          title: 'Hungry? You are so close to $name',
          body: 'You pinned this place recently, Check it out.',
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        _firebaseService
            .updateUserLocationTimestamp(pair.key.locationId.toString());
      }
    }
  }

  /// Processes TikTok links and stores them in Firestore
  /// user shares tiktok link -> app recieves tiktok
  /// mainActivity.kt captures it and saves in shared preferences
  /// flutter can then read it and create a task
  /// add to firestore which triggers a firebase function to handle processing on server
  Future<void> addFilesToProcess(List<SharedMediaFile> sharedFiles) async {
    log("Background Task Service: Processing shared files");
    List<String> urls = sharedFiles.map((f) => f.path).toList();
    FirebaseFirestore db = FirebaseFirestore.instance;

    for (String url in urls) {
      if (url.contains("tiktok.com")) {
        log("Background Task Service: Processing TikTok link: $url");
        await db.collection('incoming_tiktok_links').add({
          'url': url,
          'timestamp': FieldValue.serverTimestamp(),
        });
        log("TikTok link stored successfully: $url");
      }
    }
  }
}
