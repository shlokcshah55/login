import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:login/notifications/notificationService.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

class BackgroundTaskService {
  // Singleton pattern to ensure only one instance
  static final BackgroundTaskService _instance = BackgroundTaskService._internal();
  static final AppStateProvider _appStateProvider = AppStateProvider();

  factory BackgroundTaskService() {
    return _instance;
  }

  BackgroundTaskService._internal();

  /// Initialize Workmanager for background tasks
  Future<void> initialize() async {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Set to false in production
    );
  }

  /// Register periodic tasks
  Future<void> registerPeriodicTask(String taskName, Duration frequency) async {
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName, // Task identifier
      frequency: frequency,
      inputData: {
        'task_info': 'This is data passed to the task', // Example input data
      },
    );
  }

  /// The callback dispatcher for handling background tasks
  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      try {
        // Example background logic
        final taskInfo = inputData?['task_info'] ?? 'No task info provided';
        print('Executing background task: $task with info: $taskInfo');

        // Notify the user (example)
        await NotificationService().showNotification(
          title: 'Background Task',
          body: 'Your task "$task" completed successfully.',
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        );

        return Future.value(true); // Indicate success
      } catch (e) {
        print('Error in background task: $e');
        return Future.value(false); // Indicate failure
      }
    });
  }
}



// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
//   FlutterLocalNotificationsPlugin();

// void callbackDispatcher(String title, String body, int id) {
//   Workmanager().executeTask((task, inputData) async {
//     await showNotification(
//       title,
//       body,
//       id
//     );
//     return Future.value(true);
//   });
// }

// Future<void> initializeBackgroundTasks() async {
//   // Initialize WorkManager
//   Workmanager().initialize(
//     callbackDispatcher, // Callback function
//     isInDebugMode: true, // Set to false in production
//   );

//   // Initialize notifications
//   const AndroidInitializationSettings initializationSettingsAndroid =
//       AndroidInitializationSettings('@mipmap/ic_launcher');
//   const InitializationSettings initializationSettings =
//       InitializationSettings(android: initializationSettingsAndroid);
//   await flutterLocalNotificationsPlugin.initialize(initializationSettings);
// }

// Future<void> showNotification(String title, String body, int id) async {
//   const AndroidNotificationDetails androidPlatformChannelSpecifics = 
//     AndroidNotificationDetails(
//       'reminder_channel_id', 
//       'Reminder',
//       importance: Importance.high,
//       priority: Priority.high
//       );
    
//   const NotificationDetails platformChannelSpecifics = 
//     NotificationDetails(android: androidPlatformChannelSpecifics);

//   await flutterLocalNotificationsPlugin.show(
//     id,
//     title,
//     body,
//     platformChannelSpecifics);
// }

// Future<List<Map<String, String>>> getRestaurantsNearby() async {

// }
// final firestore = FirebaseFirestore.instance;

// void queryNearbyLocations(double centerLat, double centerLon, double radiusInKm) {
//   // Create a reference to the locations collection
//   final collectionRef = firestore.collection('locations');

//   // Create a GeoFirePoint for the center location
//   final center = geo.point(latitude: centerLat, longitude: centerLon);

//   // Use GeoFlutterFire to query locations within the radius
//   geo.collection(collectionRef: collectionRef)
//       .within(
//         center: center,
//         radius: radiusInKm,
//         field: 'geopoint', // Field in Firestore that stores GeoPoint
//       )
//       .listen((List<DocumentSnapshot> docs) {
//         for (var doc in docs) {
//           print(doc.data());
//         }
//       });
// }
