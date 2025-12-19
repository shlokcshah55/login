import 'package:flutter/animation.dart';
import 'animation_constants.dart';

/// Creates a scale animation from 0.8 to 1.0
///
/// Usage:
/// ```dart
/// Animation<double> scaleAnim = AnimationBuilders.createScaleAnimation(controller);
/// ```
class AnimationBuilders {
  AnimationBuilders._();

  /// Scale: 0.8 → 1.0
  static Animation<double> createScaleAnimation(
    AnimationController controller, {
    double begin = 0.8,
    double end = 1.0,
    Interval interval = AnimationIntervals.scaleIn,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: interval),
    );
  }

  /// Fade: 0.0 → 1.0
  static Animation<double> createFadeAnimation(
    AnimationController controller, {
    double begin = 0.0,
    double end = 1.0,
    Interval interval = AnimationIntervals.fadeIn,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: interval),
    );
  }

  /// Slide from offset to zero
  static Animation<Offset> createSlideAnimation(
    AnimationController controller, {
    required Offset begin,
    Offset end = Offset.zero,
    required Interval interval,
  }) {
    return Tween<Offset>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: interval),
    );
  }

  /// Rotation animation (subtle tilt effect)
  static Animation<double> createRotationAnimation(
    AnimationController controller, {
    double begin = -0.02,
    double end = 0.0,
    Interval interval = AnimationIntervals.rotateIn,
  }) {
    return Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: interval),
    );
  }

  /// Slide down from top (text entrance)
  static Animation<Offset> createTextSlideAnimation(
    AnimationController controller,
  ) {
    return createSlideAnimation(
      controller,
      begin: const Offset(0, -0.5),
      interval: AnimationIntervals.slideInText,
    );
  }

  /// Slide up from below (field entrance)
  static Animation<Offset> createFieldSlideAnimation(
    AnimationController controller,
  ) {
    return createSlideAnimation(
      controller,
      begin: const Offset(0, 0.5),
      interval: AnimationIntervals.slideInField,
    );
  }

  /// Slide up from bottom (button entrance)
  static Animation<Offset> createBottomSlideAnimation(
    AnimationController controller,
  ) {
    return createSlideAnimation(
      controller,
      begin: const Offset(0, 0.8),
      interval: AnimationIntervals.slideInBottom,
    );
  }

  /// Main content slide (general purpose)
  static Animation<Offset> createMainSlideAnimation(
    AnimationController controller,
  ) {
    return createSlideAnimation(
      controller,
      begin: const Offset(0, 0.3),
      interval: AnimationIntervals.slideInMain,
    );
  }
}
