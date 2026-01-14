import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:login/app/app_root.dart';
import 'package:login/bootstrap/app_bootstrap.dart';
import 'firebase_options.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📲 Background message: ${message.notification?.title}');
  print('📲 Background message body: ${message.notification?.body}');
  print('📲 Background message data: ${message.data}');
}

void main() async {
  final dependencies = await bootstrap(
    backgroundMessageHandler: _firebaseMessagingBackgroundHandler,
  );

  runApp(AppRoot(dependencies: dependencies));
}
