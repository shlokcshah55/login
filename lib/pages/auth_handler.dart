import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:login/firebase_utils/firebase_api.dart';
import 'package:login/main.dart';
import 'package:login/pages/login_page.dart';

class AuthHandler extends StatelessWidget {
  const AuthHandler({super.key});  

  @override
  Widget build(BuildContext context) {

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
            return MainScreen(userId: user.uid);
          } else {
            return LoginPage();
          }
        },
      ),  
    );
  }
}