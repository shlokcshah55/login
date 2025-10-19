import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:login/supabase/service.dart';
import 'package:login/main.dart';
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

  @override
  void initState() {
    super.initState();
    // Check auth state on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserData();
    });
  }

  void _initializeUserData() {
    final supabaseProvider = Provider.of<SupabaseService>(context, listen: false);

    if (supabaseProvider.isAuthenticated && !_hasInitializedData) {
      log("AuthHandler: Initializing user data");
      final supabaseUser = supabaseProvider.users.currentUser!;

      final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
      final locationListManager = Provider.of<LocationListManager>(context, listen: false);

      // Initialize user data and locations
      locationListManager.setUserId(supabaseUser.id);
      userDataProvider.setUserIdAndFetchData(supabaseUser.id);
      locationListManager.fetchSavedLocations();

      _hasInitializedData = true;
    } else if (!supabaseProvider.isAuthenticated) {
      // Reset flag when user logs out
      _hasInitializedData = false;
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
        // Check Supabase authentication
        if (supabaseProvider.isLoading) {
          log("AuthHandler: Waiting for Supabase auth state...");
          return const LoadingWidget();
        } else if (supabaseProvider.isAuthenticated) {
          // User is logged in with Supabase
          log("AuthHandler: User logged in with Supabase");
          return const MainScreen();
        } else {
          // Not authenticated - show welcome page
          log("AuthHandler: User not authenticated, showing welcome page");
          return const WelcomePage();
        }
      }),
    );
  }
}
