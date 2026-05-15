import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

/// Full-screen launch/splash view used during app initialization.
///
/// This is intentionally a pure "body" widget (no [Scaffold]) so it can be
/// returned from other pages as a drop-in loading state without nesting
/// scaffolds.
class LaunchSplashBody extends StatefulWidget {
  final bool immersiveSystemUi;

  const LaunchSplashBody({
    super.key,
    this.immersiveSystemUi = true,
  });

  @override
  State<LaunchSplashBody> createState() => _LaunchSplashBodyState();
}

class _LaunchSplashBodyState extends State<LaunchSplashBody> {
  bool _isDark = false;
  Timer? _colorTimer;

  @override
  void initState() {
    super.initState();

    if (widget.immersiveSystemUi) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    }

    _colorTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isDark = true;
      });
    });
  }

  @override
  void dispose() {
    _colorTimer?.cancel();
    if (widget.immersiveSystemUi) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 10),
      color: _isDark ? const Color(0xFF42133D) : const Color(0xFFEFEFEF),
      child: SizedBox.expand(
        child: Lottie.asset(
          'lib/assets/splashscren.json',
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
