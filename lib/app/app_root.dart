import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:login/app/app_providers.dart';
import 'package:login/bootstrap/app_dependencies.dart';
import 'package:login/pages/alerts_page.dart';
import 'package:login/pages/bubbles_page.dart';
import 'package:login/pages/home_page.dart';
import 'package:login/pages/profile/profile_page.dart';
import 'package:login/pages/signup_wizard/wizard_completion_page.dart';
import 'package:login/pages/auth_handler.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/services/startup_cache/startup_cache_coordinator.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/themes/pinit_theme.dart';
import 'package:login/widgets/keyboard_dismiss_drag_region.dart';
import 'package:login/widgets/profile/notifications_popover.dart';
import 'package:login/widgets/social_share_signal_host.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

// Global navigator key so services (e.g. FCMService) can navigate without BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.example.srishlok.pinit/share');
  final AnalyticsService _analyticsService = AnalyticsService();
  StreamSubscription<AuthState>? _authSubscription;
  late final StartupCacheCoordinator _startupCacheCoordinator;
  String? _lastAuthenticatedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startupCacheCoordinator = context.read<StartupCacheCoordinator>();

    _lastAuthenticatedUserId = SupabaseClientManager().currentUser?.id;
    _analyticsService.setUser(_lastAuthenticatedUserId);
    _analyticsService.startSession(reason: 'app_launch');

    _authSubscription =
        SupabaseClientManager().client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final nextUserId = session?.user.id;
      final previousUserId = _lastAuthenticatedUserId;
      if (previousUserId != null && previousUserId != nextUserId) {
        unawaited(_startupCacheCoordinator.clearUser(previousUserId));
      }
      _lastAuthenticatedUserId = nextUserId;
      if (session != null) {
        _analyticsService.setUser(session.user.id);
        _saveUserIdToAppGroup();
      } else {
        _analyticsService.setUser(null);
        _clearUserIdFromAppGroup();
      }
    });

    if (SupabaseClientManager().currentUser != null) {
      _analyticsService.setUser(SupabaseClientManager().currentUser!.id);
      _saveUserIdToAppGroup();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _analyticsService.startSession(reason: 'resume');
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _analyticsService.endSession(reason: 'background');
        break;
      case AppLifecycleState.detached:
        _analyticsService.endSession(reason: 'detached');
        break;
      case AppLifecycleState.hidden:
        _analyticsService.endSession(reason: 'hidden');
        break;
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _analyticsService.endSession(reason: 'app_dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: PinitTheme.light(),
      darkTheme: PinitTheme.dark(),
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return SocialShareSignalHost(
          child: KeyboardDismissDragRegion(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _analyticsService.registerUserInteraction(
                  interactionKey: 'pointer'),
              onPointerMove: (_) => _analyticsService.registerUserInteraction(
                  interactionKey: 'pointer'),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  _analyticsService.registerUserInteraction(
                    interactionKey: 'scroll',
                  );
                  return false;
                },
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      home: const AuthHandler(),
      routes: {
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfilePage(),
        '/alerts': (context) => const AlertsPage(),
        '/bubbles': (context) => const BubblesPage(),
        '/notifications': (context) => const NotificationsPopover(),
        '/wizardCompletion': (context) => const WizardCompletionPage(),
      },
    );
  }
}
