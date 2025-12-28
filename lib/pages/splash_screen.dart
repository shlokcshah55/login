import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'auth_handler.dart';

class SplashScreenActual extends StatefulWidget {
  const SplashScreenActual({super.key});

  @override
  State<SplashScreenActual> createState() => _SplashScreenActualState();
}

class _SplashScreenActualState extends State<SplashScreenActual> {
  // 1. Define the state for the background color
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // 2. The "Color Change" Timer - triggers after 3 seconds
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isDark = true;
        });
      }
    });

    // 3. Navigation Timer
    Timer(const Duration(milliseconds: 4000), () {
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthHandler()),
        );
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 4. Use AnimatedContainer for a smooth fade effect
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 10), // How fast the color fades
        color: _isDark ? const Color(0xFF42133D) : const Color(0xFFEFEFEF),
        child: SizedBox.expand(
          child: Lottie.asset(
            'lib/assets/splashscren.json',
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}