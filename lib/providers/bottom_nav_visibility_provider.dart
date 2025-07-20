import 'package:flutter/material.dart';
import 'dart:async';

class BottomNavVisibilityProvider with ChangeNotifier {
  bool _isVisible = true;
  Timer? _hideTimer;
  final Duration _hideDelay = const Duration(milliseconds: 2000); // 2 seconds delay before hiding

  bool get isVisible => _isVisible;

  /// Hides the bottom navigation bar immediately
  void hide() {
    if (_isVisible) {
      _isVisible = false;
      _cancelHideTimer();
      notifyListeners();
    }
  }

  /// Shows the bottom navigation bar immediately
  void show() {
    if (!_isVisible) {
      _isVisible = true;
      _cancelHideTimer();
      notifyListeners();
    }
  }

  /// Shows the bottom navigation bar temporarily, then hides it after a delay
  void showTemporarily() {
    show();
    // _startHideTimer(); // Temporarily disabled 
  }

  /// Toggles the visibility of the bottom navigation bar
  void toggle() {
    if (_isVisible) {
      hide();
    } else {
      show();
    }
  }

  /// Starts a timer to automatically hide the bottom nav after a delay
  void _startHideTimer() {
    _cancelHideTimer();
    _hideTimer = Timer(_hideDelay, () {
      hide();
    });
  }

  /// Cancels the hide timer if it's active
  void _cancelHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  @override
  void dispose() {
    _cancelHideTimer();
    super.dispose();
  }
}
