import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:login/main.dart';
import 'package:login/pages/login_page.dart';
import 'package:login/providers/location_list_manager.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/supabase_flutter/supabase_provider.dart';
import 'package:login/widgets/loading_widget.dart';
import 'package:provider/provider.dart';

class AuthHandler extends StatelessWidget {
  const AuthHandler({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the providers
    final userDataProvider =
        Provider.of<UserDataProvider>(context, listen: false);
    final locationListManager =
        Provider.of<LocationListManager>(context, listen: false);
    final supabaseProvider =
        Provider.of<SupabaseProvider>(context, listen: false);

    // Listen to auth changes from Supabase
    supabaseProvider.listenToAuthChanges(context);

    // Set up a listener for Supabase authentication status changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (supabaseProvider.isAuthenticated) {
        // When Supabase auth is successful, fetch user data
        userDataProvider.setUserIdAndFetchData(
            supabaseProvider.userRepository.currentUser?.id ?? '');
      }
    });

    return Scaffold(
      body: Builder(builder: (context) {
        // Check Supabase authentication
        if (supabaseProvider.isLoading) {
          log("AuthHandler: Waiting for Supabase auth state...");
          return const LoadingWidget();
        } else if (supabaseProvider.isAuthenticated) {
          // User is logged in with Supabase
          log("AuthHandler: User logged in with Supabase");

          // Handle Supabase authentication
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final supabaseUser = supabaseProvider.userRepository.currentUser!;

            // Use the Supabase user ID for all data fetching
            locationListManager.setUserId(supabaseUser.id);
            userDataProvider.setUserIdAndFetchData(supabaseUser.id);

            // Explicitly trigger location data loading
            locationListManager.fetchSavedLocations();
          });

          return MainScreen();
        } else {
          // Not authenticated - show login page
          return LoginPage();
        }
      }),
    );
  }
}
