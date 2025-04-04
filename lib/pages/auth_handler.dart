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

            // Trigger data fetching via UserDataProvider.
            // LocationListManager will be updated via its own listener or triggered by UserDataProvider if needed.
            // We pass the userId to both.
            locationListManager.setUserId(user.uid); // Fetches saved locations internally

            return FutureBuilder<void>(
              // Use the future from setUserIdAndFetchData to track loading
              future: userDataProvider.setUserIdAndFetchData(user.uid),
              builder: (context, futureSnapshot) {
                if (futureSnapshot.connectionState == ConnectionState.waiting) {
                   log("AuthHandler: Fetching user data...");
                  // Show loading indicator while fetching data
                  return const Center(child: CircularProgressIndicator());
                } else if (futureSnapshot.hasError) {
                  // Handle error during data fetching (e.g., user deleted in backend)
                  log("AuthHandler: Error fetching user data: ${futureSnapshot.error}");
                  // Optionally clear data again and redirect
                  // userDataProvider.clearUserData();
                  // locationListManager.setUserId(null);
                  return LoginPage(); // Redirect to LoginPage or show an error screen
                } else {
                   log("AuthHandler: User data fetched, showing MainScreen.");
                  // Data fetched successfully, show the main app screen
                  return MainScreen();
                }
              },
            );
          } else {
            // User is logged out
            log("AuthHandler: User logged out.");
            // Clear user-specific data in providers
            userDataProvider.clearUserData();
            locationListManager.setUserId(null);
            return LoginPage();
          }
        },
      ),
    );
  }
}
