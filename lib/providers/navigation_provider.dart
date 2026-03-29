import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';

class NavigationProvider with ChangeNotifier {
  int _pendingTabIndex = -1;
  LocationModel? _pendingFocusLocation;

  int get pendingTabIndex => _pendingTabIndex;
  bool get hasPendingNavigation => _pendingTabIndex >= 0;
  LocationModel? get pendingFocusLocation => _pendingFocusLocation;

  void navigateToTab(int tabIndex) {
    if (tabIndex < 0 || tabIndex > 2) {
      throw ArgumentError('Tab index must be 0, 1, or 2');
    }
    _pendingTabIndex = tabIndex;
    print('NavigationProvider: Requesting navigation to tab $tabIndex');
    notifyListeners();
  }

  void navigateToLocationOnMap(LocationModel location) {
    _pendingFocusLocation = location;
    navigateToTab(0);
  }

  void clearPendingFocusLocation() {
    _pendingFocusLocation = null;
  }

  void clearPendingNavigation() {
    _pendingTabIndex = -1;
    notifyListeners();
  }
}
