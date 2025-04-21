import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login/main.dart';
import 'package:login/pages/login_page.dart';
// import 'package:login/providers/app_data_provider.dart'; // Remove old provider
import 'package:login/providers/location_list_manager.dart'; // Import new providers
import 'package:login/providers/user_data_provider.dart';
import 'package:provider/provider.dart';

class AuthHandler extends StatelessWidget {
  const AuthHandler({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the new providers. listen: false is important here as we are calling methods, not just reading data.
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final locationListManager = Provider.of<LocationListManager>(context, listen: false);

    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            log("AuthHandler: Waiting for auth state...");
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            log("AuthHandler: Auth stream error: ${snapshot.error}");
            // Clear data on error as well? Depends on desired behavior.
            // userDataProvider.clearUserData();
            // locationListManager.setUserId(null);
            return LoginPage();
          } else if (snapshot.hasData) {
            // User is logged in
            final user = snapshot.data!;
            log("AuthHandler: User logged in: ${user.uid}");

            // Trigger data fetching via UserDataProvider outside of the build method
            // and LocationListManager operations to avoid setState during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              locationListManager.setUserId(user.uid);
              userDataProvider.setUserIdAndFetchData(user.uid);
            });

            // Check if user data is already loaded
            if (userDataProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (userDataProvider.error != null) {
              return LoginPage();
            } else {
              return MainScreen();
            }
          } else {
            // User is logged out
            log("AuthHandler: User logged out.");
            // Clear user-specific data in providers
            WidgetsBinding.instance.addPostFrameCallback((_) {
              userDataProvider.clearUserData();
              locationListManager.setUserId(null);
            });
            return LoginPage();
          }
        },
      ),
    );
  }
}