import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/bootstrap/app_dependencies.dart';
import 'package:login/firebase_options.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/services/location_service.dart';
import 'package:login/services/startup_cache/startup_cache_coordinator.dart';
import 'package:login/services/startup_cache/startup_snapshot_store.dart';
import 'package:login/supabase/service.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:package_info_plus/package_info_plus.dart';

Future<AppDependencies> bootstrap({
  required Future<void> Function(RemoteMessage) backgroundMessageHandler,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final analyticsService = AnalyticsService();

  final packageInfo = await PackageInfo.fromPlatform();
  await analyticsService.initialize(
    appVersion: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');
  } catch (e) {
    print(
        '⚠️ Firebase initialization skipped (may already be initialized): $e');
  }

  FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);
  await FCMService().registerMessageOpenHandling();

  print('🔧 Loading .env file...');
  await dotenv.load();

  // Initialize Mapbox access token. Telemetry opt-out is handled natively
  // in ios/Runner/AppDelegate.swift and android/.../MainActivity.kt — the
  // Flutter plugin (mapbox_maps_flutter 2.12.0) does not expose a Dart API
  // for it, so this has to be done on each platform's side at app launch.
  final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  mapbox.MapboxOptions.setAccessToken(mapboxToken);
  print('✅ Mapbox access token configured');

  final googlePlacesService = GooglePlacesService();
  googlePlacesService.debugApiKey();

  print('🔧 Initializing Supabase...');
  final supabaseService = SupabaseService();
  await supabaseService.initialize();
  analyticsService.setSupabaseReady();
  analyticsService.setUser(supabaseService.users.currentUser?.id);

  print('✅ Essential initialization complete!');

  final deferredInitializer = DeferredAppInitializer(
    initialize: () async {
      analyticsService.track(
        eventName: 'notification_permission_prompted',
        eventCategory: 'notification',
        properties: const <String, dynamic>{'source': 'app_bootstrap'},
      );
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        print('✅ Notification permissions: ${settings.authorizationStatus}');
        analyticsService.track(
          eventName: 'notification_permission_result',
          eventCategory: 'notification',
          properties: <String, dynamic>{
            'status': settings.authorizationStatus.name,
            'alert': settings.alert.name,
            'badge': settings.badge.name,
            'sound': settings.sound.name,
          },
        );
      } catch (e) {
        print('❌ Error requesting notification permissions: $e');
        analyticsService.track(
          eventName: 'notification_permission_result',
          eventCategory: 'notification',
          properties: <String, dynamic>{
            'status': 'error',
            'error': '$e',
          },
        );
        analyticsService.recordError(
          key: 'notification_permission_result',
          properties: <String, dynamic>{'error': '$e'},
        );
      }

      print('🔧 Initializing Location Service...');
      try {
        await LocationService().initialize();
        print('✅ Location Service initialized');
      } catch (e) {
        print('⚠️ Location Service initialization failed: $e');
      }

      print('🔧 Initializing custom marker...');
      try {
        await LocationModel.initializeCustomMarker();
        print('✅ Custom marker initialized');
      } catch (e) {
        print('⚠️ Custom marker initialization failed: $e');
        print('⚠️ App will continue without custom markers');
      }

      print('🔧 Initializing FCM...');
      try {
        await FCMService().initialize();
        print('✅ FCM initialized');
      } catch (e) {
        print('⚠️ FCM initialization failed: $e');
        print('⚠️ Push notifications may not work');
      }
    },
  );

  return AppDependencies(
    supabaseService: supabaseService,
    googlePlacesService: googlePlacesService,
    startupCacheCoordinator: StartupCacheCoordinator(
      store: JsonStartupSnapshotStore(),
    ),
    deferredInitializer: deferredInitializer,
  );
}
