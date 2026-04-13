import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:login/pages/legal_consent_gate_page.dart';
import 'package:login/supabase/service.dart';
import 'package:login/pages/main_screen.dart';
import 'package:login/pages/welcome_page.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/widgets/loading_widget.dart';
import 'package:provider/provider.dart';

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
  String? _legalConsentCheckedUserId;
  bool? _hasAcceptedLegalConsent;

  @override
  void initState() {
    super.initState();
    // Check auth state on first build
    _scheduleInitialization();
  }

  void _scheduleInitialization() {
    if (_initCallScheduled) return; // Prevent multiple scheduling
    _initCallScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCallScheduled = false;
      _initializeUserData();
    });
  }

  Future<void> _initializeUserData() async {
    // Prevent concurrent initialization
    if (_isInitializing) return;

    final supabaseProvider =
        Provider.of<SupabaseService>(context, listen: false);

    if (supabaseProvider.isAuthenticated && !_hasInitializedData) {
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
      final supabaseUser = supabaseProvider.users.currentUser!;

      final userDataProvider =
          Provider.of<UserDataProvider>(context, listen: false);
      final locationListManager =
          Provider.of<LocationListManager>(context, listen: false);

      // Initialize user data and locations
      // setUserId already calls fetchSavedLocations() internally, no need to call it again
      locationListManager.setUserId(supabaseUser.id);

      // Use cached profile if available (from signIn), otherwise fetch
      final cachedProfile = supabaseProvider.cachedUserProfile;
      if (cachedProfile != null) {
        log("AuthHandler: Using cached user profile from sign-in");
        await userDataProvider.setUserIdAndFetchData(supabaseUser.id,
            cachedProfile: cachedProfile);
        supabaseProvider.clearCachedUserProfile(); // Clear after use
      } else {
        await userDataProvider.setUserIdAndFetchData(supabaseUser.id);
      }

      _hasInitializedData = true;
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } else if (!supabaseProvider.isAuthenticated) {
      // Reset flags when user logs out
      _hasInitializedData = false;
      _isInitializing = false;
      _isCheckingLegalConsent = false;
      _legalConsentCheckedUserId = null;
      _hasAcceptedLegalConsent = null;
    }
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

    final hasAccepted =
        await supabaseProvider.users.hasAcceptedLegalConsent(currentUser.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingLegalConsent = false;
      _legalConsentCheckedUserId = currentUser.id;
      _hasAcceptedLegalConsent = hasAccepted;
    });
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
      _scheduleInitialization();
    }

    final currentUserId = supabaseProvider.users.currentUser?.id;
    final needsLegalConsentRefresh = supabaseProvider.isAuthenticated &&
        supabaseProvider.hasValidSession &&
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
          return const LoadingWidget();
        }

        if (supabaseProvider.isAuthenticated &&
            !supabaseProvider.hasValidSession) {
          return const LoadingWidget();
        }

        if (_isCheckingLegalConsent ||
            (supabaseProvider.isAuthenticated &&
                supabaseProvider.hasValidSession &&
                currentUserId != null &&
                _legalConsentCheckedUserId != currentUserId)) {
          return const LoadingWidget();
        }

        // Check Supabase authentication and session validity
        if (supabaseProvider.isAuthenticated &&
            supabaseProvider.hasValidSession) {
          // Show loading while initializing user data
          final userDataProvider =
              Provider.of<UserDataProvider>(context, listen: false);
          if (_isInitializing ||
              (userDataProvider.isLoading &&
                  userDataProvider.supabaseUserData == null)) {
            return const LoadingWidget();
          }

          // User is logged in with valid session
          log("AuthHandler: User logged in with valid session, showing MainScreen");

          if (_hasAcceptedLegalConsent == false) {
            return LegalConsentGatePage(
              onAccept: _acceptLegalConsent,
            );
          }

          // Show MainScreen - wizard completion handled via popover
          return const MainScreen();
        } else {
          // Not authenticated or session invalid - show welcome page
          log("AuthHandler: User not authenticated or session invalid, showing welcome page");
          return const WelcomePage();
        }
      }),
    );
  }
}
