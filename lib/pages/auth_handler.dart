import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login/main.dart';
import 'package:login/pages/login_page.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:provider/provider.dart';

class AuthHandler extends StatelessWidget {
  const AuthHandler({super.key});

  @override
  Widget build(BuildContext context) {
    final appStateProvider_ = Provider.of<AppStateProvider>(context, listen: false);

    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return LoginPage();
          } else if (snapshot.hasData) {
            final user = snapshot.data!;
            appStateProvider_.userId = user.uid;

            return FutureBuilder<void>(
              future: appStateProvider_.fetchUserData(),
              builder: (context, futureSnapshot) {
                if (futureSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (futureSnapshot.hasError) {
                  // Handle error during data fetching
                  return LoginPage(); // Redirect to LoginPage or show an error screen
                } else {
                  return MainScreen();
                }
              },
            );
          } else {
            return LoginPage();
          }
        },
      ),
    );
  }
}
