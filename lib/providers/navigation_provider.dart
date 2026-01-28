import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _pendingTabIndex = -1;

  int get pendingTabIndex => _pendingTabIndex;
  bool get hasPendingNavigation => _pendingTabIndex >= 0;

  void navigateToTab(int tabIndex) {
    if (tabIndex < 0 || tabIndex > 2) {
      throw ArgumentError('Tab index must be 0, 1, or 2');
    }
    _pendingTabIndex = tabIndex;
    print('NavigationProvider: Requesting navigation to tab $tabIndex');
    notifyListeners();
  }

  void clearPendingNavigation() {
    _pendingTabIndex = -1;
    notifyListeners();
  }
}
