import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login/main.dart';
import 'package:login/pages/login_page.dart';
import 'package:login/providers/location_list_manager.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/supabase_flutter/supabase_provider.dart';
import 'package:provider/provider.dart';

class AuthHandler extends StatelessWidget {
  const AuthHandler({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the providers - Firebase (legacy) and Supabase (new)
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final locationListManager = Provider.of<LocationListManager>(context, listen: false);
    final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

    // Listen to auth changes from Supabase
    supabaseProvider.listenToAuthChanges(context);
    
    // Set up a listener for Supabase authentication status changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (supabaseProvider.isAuthenticated) {
        // When Supabase auth is successful, we still want to fetch user data
        // This will prioritize Supabase data but fall back to Firebase if needed
        userDataProvider.setUserIdAndFetchData(supabaseProvider.userRepository.currentUser?.id ?? '');;
      }
    });

    return Scaffold(
      body: Builder(
        builder: (context) {
          // Check Supabase authentication first
          if (supabaseProvider.isLoading) {
            log("AuthHandler: Waiting for Supabase auth state...");
            return const Center(child: CircularProgressIndicator());
          } else if (supabaseProvider.isAuthenticated) {
            // User is logged in with Supabase
            log("AuthHandler: User logged in with Supabase");
            
            // Continue using existing providers for now during migration
            // In the future, this would be fully migrated to use Supabase repositories
            
            // For now, we manually trigger the Firebase auth for compatibility
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final user = FirebaseAuth.instance.currentUser;
              final supabaseUser = supabaseProvider.userRepository.currentUser;
              
              // We need both the Firebase and Supabase user identifiers during migration
              if (user != null) {
                locationListManager.setUserId(user.uid);
                userDataProvider.setUserIdAndFetchData(user.uid);
              } else if (supabaseUser != null) {
                // If Firebase auth is not available but Supabase is,
                // use the Supabase ID for location fetching
                locationListManager.setUserId(supabaseUser.id);
                userDataProvider.setUserIdAndFetchData(supabaseUser.id);
              }
              
              // Explicitly trigger location data loading
              locationListManager.fetchSavedLocations();
            });
            
            return MainScreen();
          } else {
            // Fallback to Firebase auth during migration
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  log("AuthHandler: Waiting for Firebase auth state...");
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  log("AuthHandler: Firebase auth stream error: ${snapshot.error}");
                  return LoginPage();
                } else if (snapshot.hasData) {
                  // User is logged in with Firebase
                  final user = snapshot.data!;
                  log("AuthHandler: User logged in with Firebase: ${user.uid}");

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    locationListManager.setUserId(user.uid);
                    userDataProvider.setUserIdAndFetchData(user.uid);
                  });

                  if (userDataProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (userDataProvider.error != null) {
                    return LoginPage();
                  } else {
                    // Make sure we trigger location data loading as well
                    locationListManager.fetchSavedLocations();
                    return MainScreen();
                  }
                } else {
                  // User is logged out
                  log("AuthHandler: User logged out.");
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    userDataProvider.clearUserData();
                    locationListManager.setUserId(null);
                  });
                  return LoginPage();
                }
              },
            );
          }
        }
      ),
    );
  }
}