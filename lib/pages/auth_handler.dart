import 'dart:developer';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    // Check auth state on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
    });
  }

  Future<void> _initializeUserData() async {
    final supabaseProvider = Provider.of<SupabaseService>(context, listen: false);

    if (supabaseProvider.isAuthenticated && !_hasInitializedData) {
      setState(() {
        _isInitializing = true;
      });

      log("AuthHandler: Validating session before initializing user data");

      // Validate session before proceeding
      final isValid = await supabaseProvider.validateAndRefreshSession();

      if (!isValid) {
        log("AuthHandler: Session validation failed, aborting initialization");
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

      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      final locationListManager = Provider.of<LocationListManager>(context, listen: false);

      // Initialize user data and locations
      // setUserId already calls fetchSavedLocations() internally, no need to call it again
      locationListManager.setUserId(supabaseUser.id);
      await userDataProvider.setUserIdAndFetchData(supabaseUser.id);

      _hasInitializedData = true;
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } else if (!supabaseProvider.isAuthenticated) {
      // Reset flag when user logs out
      _hasInitializedData = false;
      _isInitializing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to SupabaseProvider changes - widget rebuilds when auth state changes
    final supabaseProvider = Provider.of<SupabaseService>(context, listen: true);

    // Re-initialize data when auth state changes to authenticated
    if (supabaseProvider.isAuthenticated && !_hasInitializedData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeUserData();
      });
    }

    return Scaffold(
      body: Builder(builder: (context) {
        // Show loading during session validation
        if (supabaseProvider.isValidatingSession) {
          return const LoadingWidget();
        }

        // Check Supabase authentication and session validity
        if (supabaseProvider.isAuthenticated && supabaseProvider.hasValidSession) {
          // Show loading while initializing user data
          final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
          if (_isInitializing || (userDataProvider.isLoading && userDataProvider.supabaseUserData == null)) {
            return const LoadingWidget();
          }

          // User is logged in with valid session
          log("AuthHandler: User logged in with valid session, showing MainScreen");

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
