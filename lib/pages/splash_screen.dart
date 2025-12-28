import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'auth_handler.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Hide system UI overlays for fullscreen experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    Timer(const Duration(milliseconds: 4000), () {
      if (mounted) {
        // Restore system UI before navigating away
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthHandler()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: SizedBox.expand(
          child: Lottie.asset(
            'lib/assets/splashscren.json',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
