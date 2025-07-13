import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'auth_handler.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool showLoadedAnimation = false;

  @override
  void initState() {
    super.initState();
    // Show loading animation for 2 seconds, then switch to loaded animation
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          showLoadedAnimation = true;
        });
        // After loaded animation plays for 1 second, navigate to AuthHandler
        Timer(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AuthHandler()),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Lottie.asset(
          'lib/assets/iPhone 14 Pro Max  1.json',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
