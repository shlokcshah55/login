import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/location_model.dart';
import 'package:login/notifications/notificationService.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:login/services/firebase_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:location/location.dart';

class BackgroundTaskService {
  // Singleton pattern to ensure only one instance
  static final BackgroundTaskService _instance = BackgroundTaskService._internal();
  static final AppStateProvider _appStateProvider = AppStateProvider();
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

    await Workmanager().registerPeriodicTask(
      'LocationChecker',
      'LocationChecker', // Task identifier
      frequency: const Duration(minutes: 15),
    );
  
  }

   static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      try {
        Location location = Location();

        // Ensure permissions and services are enabled
        bool serviceEnabled = await location.serviceEnabled();
        if (!serviceEnabled) {
          serviceEnabled = await location.requestService();
          if (!serviceEnabled) {
            return Future.value(false); // Location service not available
          }
        }

        PermissionStatus permissionGranted = await location.hasPermission();
        if (permissionGranted == PermissionStatus.denied) {
          permissionGranted = await location.requestPermission();
          if (permissionGranted != PermissionStatus.granted) {
            return Future.value(false); // Location permission not granted
          }
        }
        // Get the user's location
        LocationData currentLocation = await location.getLocation();
        
        try {
          Map<LocationModel,Timestamp> locations = await _firebaseService.getSavedLocationsMap();
            for (var pair in locations.entries) {
              if (pair.key.isWithinRadius(1, currentLocation.latitude ?? 0, currentLocation.longitude?? 0) && 
                  pair.value.toDate().isBefore(DateTime.now().subtract(Duration(hours: 24)))) {
                String name = pair.key.name;
                await NotificationService().showNotification(
                title: 'Hungry? You are so close to $name',
                body: 'You pinned this place recently, Check it out.', 
                id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              );
            _firebaseService.updateUserLocationTimestamp(pair.key.id);
            }
          }
        } catch (e) {
          return Future.value(false); // Indicate failure
        }
    } catch (e) {
      print('Error in background task: $e');
      return Future.value(false); // Task failed
    }
  return Future.value(true);
  });
  }

}





