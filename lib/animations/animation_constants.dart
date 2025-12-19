import 'package:flutter/animation.dart';

/// Standard animation durations used throughout the app
class AnimationDurations {
  AnimationDurations._(); // Private constructor - this is a constants class

  /// Fast interactions (200ms) - Button presses, quick feedback
  static const fast = Duration(milliseconds: 200);

  /// Medium transitions (600ms) - Page/widget entrance
  static const medium = Duration(milliseconds: 600);

  /// Slow entrances (700-800ms) - Complex multi-step animations
  static const slow = Duration(milliseconds: 700);

  /// Signup wizard specific (700ms)
  static const signupTransition = Duration(milliseconds: 700);
}

/// Common curve and interval combinations
class AnimationIntervals {
  AnimationIntervals._();

  // Scale animations
  static const scaleIn = Interval(0.0, 0.6, curve: Curves.easeOutBack);

  // Fade animations
  static const fadeIn = Interval(0.0, 0.5, curve: Curves.easeInOut);

  // Slide animations
  static const slideInMain = Interval(0.0, 0.7, curve: Curves.easeOutCubic);
  static const slideInText = Interval(0.0, 0.4, curve: Curves.easeOut);
  static const slideInField = Interval(0.1, 0.6, curve: Curves.easeOutBack);
  static const slideInBottom = Interval(0.2, 0.8, curve: Curves.easeOutCubic);

  // Rotation animations
  static const rotateIn = Interval(0.0, 0.8, curve: Curves.easeOutBack);
}
