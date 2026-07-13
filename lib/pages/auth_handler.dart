import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:login/pages/legal_consent_gate_page.dart';
import 'package:login/pages/reset_password_page.dart';
import 'package:login/pages/signup_wizard/wizard_completion_page.dart';
import 'package:login/supabase/service.dart';
import 'package:login/pages/main_screen.dart';
import 'package:login/pages/welcome_page.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/startup_cache/startup_cache_coordinator.dart';
import 'package:login/widgets/launch_splash_body.dart';
import 'package:login/widgets/startup_cache_status_banner.dart';
import 'package:provider/provider.dart';

enum AuthenticatedStartupSurface { splash, legalConsent, home }

@visibleForTesting
AuthenticatedStartupSurface resolveAuthenticatedStartupSurface({
  required bool hasValidSession,
  required bool hasProfile,
  required bool hasSavedLocations,
  required bool hasCurrentConsent,
}) {
  if (!hasValidSession || !hasProfile || !hasSavedLocations) {
    return AuthenticatedStartupSurface.splash;
  }
  if (!hasCurrentConsent) {
    return AuthenticatedStartupSurface.legalConsent;
  }
  return AuthenticatedStartupSurface.home;
}

@visibleForTesting
bool shouldPresentWizardCompletionAfterOAuthSignIn({
  required bool pendingOAuthWizardRouting,
  required bool wizardCompleted,
}) {
  return pendingOAuthWizardRouting && !wizardCompleted;
}

class AuthHandler extends StatefulWidget {
  const AuthHandler({super.key});

  @override
  State<AuthHandler> createState() => _AuthHandlerState();
}

class _AuthHandlerState extends State<AuthHandler> {
  bool _hasInitializedData = false;
  bool _isInitializing = false;
  bool _isCheckingLegalConsent = false;
  bool _initCallScheduled = false; // Prevents multiple post-frame callbacks
  bool _logoutCleanupScheduled = false;
  bool _hasCleanedLoggedOutState = false;
  bool _wizardCompletionRouteScheduled = false;
  String? _legalConsentCheckedUserId;
  bool? _hasAcceptedLegalConsent;
  UserDataProvider? _observedUserDataProvider;
  LocationListManager? _observedLocationListManager;
  String? _observedCacheUserId;

  @override
  void initState() {
    super.initState();
    // Check auth state on first build
    _scheduleInitialization();

    // Listen for password recovery deep link (Supabase fires this after the
    // user taps the reset-password email link).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);
      supabaseProvider.passwordRecoveryRequested
          .addListener(_onPasswordRecoveryRequested);
      // Handle the case where recovery was already requested before this
      // widget mounted (e.g. cold start via deep link).
      if (supabaseProvider.passwordRecoveryRequested.value) {
        _onPasswordRecoveryRequested();
      }
    });
  }

  @override
  void dispose() {
    _detachCachePersistenceListeners();
    // Defensive: provider is a singleton so it outlives this widget.
    try {
      Provider.of<SupabaseService>(context, listen: false)
          .passwordRecoveryRequested
          .removeListener(_onPasswordRecoveryRequested);
    } catch (_) {}
    super.dispose();
  }

  void _onPasswordRecoveryRequested() {
    if (!mounted) return;
    final supabaseProvider =
        Provider.of<SupabaseService>(context, listen: false);
    if (!supabaseProvider.passwordRecoveryRequested.value) return;

    // Push the reset page on top of whatever is currently shown.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => const ResetPasswordPage(),
        fullscreenDialog: true,
      ),
    );
  }

  void _scheduleInitialization() {
    if (_initCallScheduled) return; // Prevent multiple scheduling
    _initCallScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCallScheduled = false;
      _initializeUserData();
    });
  }

  void _scheduleLoggedOutCleanup() {
    if (_logoutCleanupScheduled || _hasCleanedLoggedOutState) return;
    _logoutCleanupScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _logoutCleanupScheduled = false;
      if (!mounted) return;

      _detachCachePersistenceListeners();
      await context.read<StartupCacheCoordinator>().clearActiveUser();
      if (!mounted) return;
      await context.read<UserDataProvider>().clearUserData();
      if (!mounted) return;
      context.read<LocationListManager>().clearData();

      _hasCleanedLoggedOutState = true;
    });
  }

  Future<void> _initializeUserData() async {
    // Prevent concurrent initialization
    if (_isInitializing) return;

    final supabaseProvider =
        Provider.of<SupabaseService>(context, listen: false);

    if (supabaseProvider.isAuthenticated && !_hasInitializedData) {
      _hasCleanedLoggedOutState = false;
      setState(() {
        _isInitializing = true;
      });

      // REMOVED: Redundant validateAndRefreshSession() call
      // Session is already validated in SupabaseService.initialize()
      // and kept valid by the auth listener. Trust hasValidSession flag.

      if (!supabaseProvider.hasValidSession) {
        log("AuthHandler: No valid session, aborting initialization");
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _hasInitializedData = false;
          });
        }
        return;
      }

      log("AuthHandler: Session valid, initializing user data");
      final supabaseUser = supabaseProvider.users.currentUser;
      if (supabaseUser == null) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _hasInitializedData = false;
          });
        }
        return;
      }
      final userId = supabaseUser.id;

      final userDataProvider =
          Provider.of<UserDataProvider>(context, listen: false);
      final locationListManager =
          Provider.of<LocationListManager>(context, listen: false);
      final cacheCoordinator = context.read<StartupCacheCoordinator>();

      _detachCachePersistenceListeners();
      final previousCacheUserId = cacheCoordinator.activeUserId;
      if (previousCacheUserId != null && previousCacheUserId != userId) {
        await cacheCoordinator.clearUser(previousCacheUserId);
        if (!_isActiveUser(userId)) return;
      }

      // Establish the user scope before reading disk. Other background location
      // services may start, but the saved-location request is coordinated below.
      locationListManager.setUserId(userId, fetchSavedLocations: false);
      final hydration = await cacheCoordinator.hydrate(
        userId: userId,
        userDataProvider: userDataProvider,
        locationListManager: locationListManager,
      );
      if (!_isActiveUser(userId)) return;

      _attachCachePersistenceListeners(
        userId: userId,
        userDataProvider: userDataProvider,
        locationListManager: locationListManager,
      );

      final hasCachedBaseData =
          hydration.profileHydrated && hydration.savedLocationsHydrated;
      final refresh = _refreshAuthenticatedData(
        userId: userId,
        userDataProvider: userDataProvider,
        locationListManager: locationListManager,
        cacheCoordinator: cacheCoordinator,
      );

      if (hasCachedBaseData) {
        _hasInitializedData = true;
        setState(() {
          _isInitializing = false;
          _legalConsentCheckedUserId = userId;
          _hasAcceptedLegalConsent = hydration.hasCurrentConsent;
        });
        unawaited(refresh);
        return;
      }

      await refresh;
      if (!_isActiveUser(userId)) return;

      _hasInitializedData = true;
      setState(() {
        _isInitializing = false;
      });
    } else if (!supabaseProvider.isAuthenticated) {
      // Reset flags when user logs out
      _hasInitializedData = false;
      _isInitializing = false;
      _isCheckingLegalConsent = false;
      _legalConsentCheckedUserId = null;
      _hasAcceptedLegalConsent = null;
    }
  }

  Future<void> _refreshAuthenticatedData({
    required String userId,
    required UserDataProvider userDataProvider,
    required LocationListManager locationListManager,
    required StartupCacheCoordinator cacheCoordinator,
  }) async {
    if (!_isActiveUser(userId)) return;
    cacheCoordinator.markRefreshStarted();

    final supabaseProvider = context.read<SupabaseService>();
    final cachedProfile = supabaseProvider.cachedUserProfile;
    if (cachedProfile != null) {
      supabaseProvider.clearCachedUserProfile();
    }

    final profileRefresh = userDataProvider.setUserIdAndFetchData(
      userId,
      cachedProfile: cachedProfile,
    );
    final savedLocationsRefresh =
        locationListManager.fetchSavedLocations(force: true);
    final consentRefresh = supabaseProvider.users.getLegalConsentStatus(userId);

    final results = await Future.wait<dynamic>([
      profileRefresh,
      savedLocationsRefresh,
      consentRefresh,
    ]);
    if (!_isActiveUser(userId)) return;

    final serverConsent = results[2] as bool?;
    setState(() {
      _legalConsentCheckedUserId = userId;
      if (serverConsent != null) {
        _hasAcceptedLegalConsent = serverConsent;
      } else {
        _hasAcceptedLegalConsent ??= false;
      }
    });

    if (serverConsent == true) {
      cacheCoordinator.markConsentAccepted(
        userId: userId,
        profile: userDataProvider.supabaseUserData,
        savedLocations: locationListManager.savedLocations.keys.toList(),
      );
    } else if (serverConsent == false) {
      cacheCoordinator.clearConsentAcceptance(
        userId: userId,
        profile: userDataProvider.supabaseUserData,
        savedLocations: locationListManager.savedLocations.keys.toList(),
      );
    }

    final hadFailure = userDataProvider.error != null ||
        locationListManager.isSavedDataStale ||
        serverConsent == null;
    cacheCoordinator.markRefreshCompleted(hadFailure: hadFailure);
    _scheduleCurrentSnapshotWrite();
  }

  bool _isActiveUser(String userId) {
    if (!mounted) return false;
    final supabaseProvider = context.read<SupabaseService>();
    return supabaseProvider.isAuthenticated &&
        supabaseProvider.hasValidSession &&
        supabaseProvider.users.currentUser?.id == userId;
  }

  void _attachCachePersistenceListeners({
    required String userId,
    required UserDataProvider userDataProvider,
    required LocationListManager locationListManager,
  }) {
    if (_observedCacheUserId == userId &&
        identical(_observedUserDataProvider, userDataProvider) &&
        identical(_observedLocationListManager, locationListManager)) {
      return;
    }
    _detachCachePersistenceListeners();
    _observedCacheUserId = userId;
    _observedUserDataProvider = userDataProvider;
    _observedLocationListManager = locationListManager;
    userDataProvider.addListener(_scheduleCurrentSnapshotWrite);
    locationListManager.addListener(_scheduleCurrentSnapshotWrite);
    _scheduleCurrentSnapshotWrite();
  }

  void _detachCachePersistenceListeners() {
    _observedUserDataProvider?.removeListener(_scheduleCurrentSnapshotWrite);
    _observedLocationListManager?.removeListener(_scheduleCurrentSnapshotWrite);
    _observedCacheUserId = null;
    _observedUserDataProvider = null;
    _observedLocationListManager = null;
  }

  void _scheduleCurrentSnapshotWrite() {
    if (!mounted) return;
    final userId = _observedCacheUserId;
    final userDataProvider = _observedUserDataProvider;
    final locationListManager = _observedLocationListManager;
    if (userId == null ||
        userDataProvider == null ||
        locationListManager == null) {
      return;
    }
    context.read<StartupCacheCoordinator>().scheduleWrite(
          userId: userId,
          profile: userDataProvider.supabaseUserData,
          savedLocations: locationListManager.savedLocations.keys.toList(),
        );
  }

  void _scheduleLegalConsentCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLegalConsentStatus();
    });
  }

  Future<void> _checkLegalConsentStatus() async {
    if (_isCheckingLegalConsent || !mounted) {
      return;
    }

    final supabaseProvider =
        Provider.of<SupabaseService>(context, listen: false);
    final currentUser = supabaseProvider.users.currentUser;
    if (currentUser == null) {
      return;
    }

    setState(() {
      _isCheckingLegalConsent = true;
    });

    final serverConsent =
        await supabaseProvider.users.getLegalConsentStatus(currentUser.id);
    final hasAccepted = serverConsent ?? false;

    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingLegalConsent = false;
      _legalConsentCheckedUserId = currentUser.id;
      _hasAcceptedLegalConsent = hasAccepted;
    });

    final userDataProvider = context.read<UserDataProvider>();
    final locationListManager = context.read<LocationListManager>();
    final cacheCoordinator = context.read<StartupCacheCoordinator>();
    if (hasAccepted) {
      cacheCoordinator.markConsentAccepted(
        userId: currentUser.id,
        profile: userDataProvider.supabaseUserData,
        savedLocations: locationListManager.savedLocations.keys.toList(),
      );
    } else if (serverConsent == false) {
      cacheCoordinator.clearConsentAcceptance(
        userId: currentUser.id,
        profile: userDataProvider.supabaseUserData,
        savedLocations: locationListManager.savedLocations.keys.toList(),
      );
    }
  }

  Future<void> _acceptLegalConsent() async {
    final supabaseProvider =
        Provider.of<SupabaseService>(context, listen: false);
    final currentUser = supabaseProvider.users.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    await supabaseProvider.users.acceptLegalConsent(currentUser.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _legalConsentCheckedUserId = currentUser.id;
      _hasAcceptedLegalConsent = true;
    });

    final userDataProvider = context.read<UserDataProvider>();
    final locationListManager = context.read<LocationListManager>();
    context.read<StartupCacheCoordinator>().markConsentAccepted(
          userId: currentUser.id,
          profile: userDataProvider.supabaseUserData,
          savedLocations: locationListManager.savedLocations.keys.toList(),
        );
  }

  void _scheduleWizardCompletionRoute() {
    if (_wizardCompletionRouteScheduled) return;
    _wizardCompletionRouteScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      context.read<SupabaseService>().clearPendingOAuthWizardRouting();

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const WizardCompletionPage(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _wizardCompletionRouteScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to SupabaseProvider changes - widget rebuilds when auth state changes
    final supabaseProvider =
        Provider.of<SupabaseService>(context, listen: true);

    // Re-initialize data when auth state changes to authenticated
    // Use flag to prevent multiple post-frame callbacks
    if (supabaseProvider.isAuthenticated &&
        !_hasInitializedData &&
        !_isInitializing) {
      _hasCleanedLoggedOutState = false;
      _scheduleInitialization();
    }

    if (!supabaseProvider.isAuthenticated) {
      _hasInitializedData = false;
      _isInitializing = false;
      _isCheckingLegalConsent = false;
      _legalConsentCheckedUserId = null;
      _hasAcceptedLegalConsent = null;
      _scheduleLoggedOutCleanup();
    }

    final currentUserId = supabaseProvider.users.currentUser?.id;
    final needsLegalConsentRefresh = supabaseProvider.isAuthenticated &&
        supabaseProvider.hasValidSession &&
        _hasInitializedData &&
        !_isInitializing &&
        currentUserId != null &&
        _legalConsentCheckedUserId != currentUserId &&
        !_isCheckingLegalConsent;

    if (needsLegalConsentRefresh) {
      _scheduleLegalConsentCheck();
    }

    return Scaffold(
      body: Builder(builder: (context) {
        // Show loading during session validation
        if (supabaseProvider.isValidatingSession) {
          return const LaunchSplashBody();
        }

        if (supabaseProvider.isAuthenticated &&
            !supabaseProvider.hasValidSession) {
          return const LaunchSplashBody();
        }

        // Check Supabase authentication and session validity
        if (supabaseProvider.isAuthenticated &&
            supabaseProvider.hasValidSession) {
          final userDataProvider =
              Provider.of<UserDataProvider>(context, listen: true);
          final locationListManager =
              Provider.of<LocationListManager>(context, listen: true);

          if (!_hasInitializedData ||
              _isCheckingLegalConsent ||
              currentUserId == null ||
              _legalConsentCheckedUserId != currentUserId) {
            return const LaunchSplashBody();
          }

          final startupSurface = resolveAuthenticatedStartupSurface(
            hasValidSession: supabaseProvider.hasValidSession,
            hasProfile: userDataProvider.supabaseUserData != null,
            hasSavedLocations: locationListManager.hasLoadedSavedLocations,
            hasCurrentConsent: _hasAcceptedLegalConsent == true,
          );
          if (startupSurface == AuthenticatedStartupSurface.splash) {
            return const LaunchSplashBody();
          }
          if (startupSurface == AuthenticatedStartupSurface.legalConsent) {
            return LegalConsentGatePage(
              onAccept: _acceptLegalConsent,
            );
          }

          log("AuthHandler: User logged in with valid session, showing MainScreen");

          final userProfile = userDataProvider.supabaseUserData;
          final shouldPresentWizard = userProfile != null &&
              shouldPresentWizardCompletionAfterOAuthSignIn(
                pendingOAuthWizardRouting:
                    supabaseProvider.pendingOAuthWizardRouting,
                wizardCompleted: userProfile.wizardCompleted,
              );

          if (!shouldPresentWizard &&
              supabaseProvider.pendingOAuthWizardRouting &&
              userProfile?.wizardCompleted == true) {
            supabaseProvider.clearPendingOAuthWizardRouting();
          }

          if (shouldPresentWizard) {
            _scheduleWizardCompletionRoute();
            return const LaunchSplashBody();
          }

          // Show MainScreen - wizard completion handled via popover
          return const StartupCacheStatusBanner(
            child: MainScreen(),
          );
        } else {
          // Not authenticated or session invalid - show welcome page
          log("AuthHandler: User not authenticated or session invalid, showing welcome page");
          return const WelcomePage();
        }
      }),
    );
  }
}
