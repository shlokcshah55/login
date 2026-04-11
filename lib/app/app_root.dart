import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:login/app/app_providers.dart';
import 'package:login/bootstrap/app_dependencies.dart';
import 'package:login/pages/alerts_page.dart';
import 'package:login/pages/bubbles_page.dart';
import 'package:login/pages/home_page.dart';
import 'package:login/pages/profile/profile_page.dart';
import 'package:login/pages/signup_wizard/wizard_completion_page.dart';
import 'package:login/pages/splash_screen.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/themes/pinit_theme.dart';

class AppRoot extends StatelessWidget {
  final AppDependencies dependencies;

  const AppRoot({Key? key, required this.dependencies}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      dependencies: dependencies,
      child: const MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel('com.example.srishlok.pinit/share');
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    SupabaseClientManager().client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _saveUserIdToAppGroup();
      } else {
        _clearUserIdFromAppGroup();
      }
    });

    if (SupabaseClientManager().currentUser != null) {
      _saveUserIdToAppGroup();
    }
  }

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

  Future<void> _clearUserIdFromAppGroup() async {
    try {
      await platform.invokeMethod('clearUserId');
      print("✅ Cleared user ID from App Group");
    } catch (e) {
      print("❌ Error clearing user ID from App Group: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: PinitTheme.light(),
      darkTheme: PinitTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const SplashScreenActual(),
      routes: {
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfilePage(),
        '/alerts': (context) => const AlertsPage(),
        '/bubbles': (context) => const BubblesPage(),
        '/wizardCompletion': (context) => const WizardCompletionPage(),
      },
    );
  }
}
