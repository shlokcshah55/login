import 'package:flutter/material.dart';
import 'dart:async';

class BottomNavVisibilityProvider with ChangeNotifier {
  bool _isVisible = true;
  bool _isLocked = false;
  bool _isPinned = true;
  Timer? _hideTimer;
  final Duration _hideDelay =
      const Duration(milliseconds: 2000); // 2 seconds delay before hiding

  bool get isVisible => _isVisible;
  bool get isLocked => _isLocked;
  bool get isPinned => _isPinned;

  /// Toggles pinned state. When pinned, the nav bar stays always visible
  /// and ignores scroll-based hide/show calls.
  void togglePinned() {
    _isPinned = !_isPinned;
    if (_isPinned) {
      _cancelHideTimer();
      _isVisible = true;
    }
    notifyListeners();
  }

  /// Locks the nav bar hidden state until unlocked.
  void setLocked(bool locked) {
    if (_isLocked == locked) return;

    _isLocked = locked;
    if (_isLocked) {
      _isVisible = false;
      _cancelHideTimer();
    }
    notifyListeners();
  }

  /// Hides the bottom navigation bar immediately
  void hide() {
    if (_isPinned) return;
    if (_isVisible) {
      _isVisible = false;
      _cancelHideTimer();
      notifyListeners();
    }
  }

  /// Shows the bottom navigation bar immediately
  void show() {
    if (_isLocked) return;
    if (!_isVisible) {
      _isVisible = true;
      _cancelHideTimer();
      notifyListeners();
    }
  }

  /// Shows the bottom navigation bar temporarily, then hides it after a delay
  void showTemporarily() {
    if (_isLocked) return;
    if (_isPinned) return;
    _isVisible = true;
    _startHideTimer();
    notifyListeners();
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
