import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/bootstrap/app_dependencies.dart';
import 'package:login/firebase_options.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/supabase/service.dart';

Future<AppDependencies> bootstrap({
  required Future<void> Function(RemoteMessage) backgroundMessageHandler,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');
  } catch (e) {
    print('⚠️ Firebase initialization skipped (may already be initialized): $e');
  }

  FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);

  FirebaseMessaging.instance
      .requestPermission(alert: true, badge: true, sound: true)
      .then((settings) {
    print('✅ Notification permissions: ${settings.authorizationStatus}');
  }).catchError((e) {
    print('❌ Error requesting notification permissions: $e');
  });

  print('🔧 Initializing custom marker...');
  await LocationModel.initializeCustomMarker();

  print('🔧 Loading .env file...');
  await dotenv.load();

  final googlePlacesService = GooglePlacesService();
  googlePlacesService.debugApiKey();

  print('🔧 Initializing Supabase...');
  final supabaseService = SupabaseService();
  await supabaseService.initialize();

  print('✅ All initialization complete!');

  FCMService().initialize().catchError((e) {
    print('❌ Error initializing FCM: $e');
  });

  return AppDependencies(
    supabaseService: supabaseService,
    googlePlacesService: googlePlacesService,
  );
}
