import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';

class NavigationProvider with ChangeNotifier {
  int _pendingTabIndex = -1;
  LocationModel? _pendingFocusLocation;
  bool _pendingOpenHomeSearch = false;

  int get pendingTabIndex => _pendingTabIndex;
  bool get hasPendingNavigation => _pendingTabIndex >= 0;
  LocationModel? get pendingFocusLocation => _pendingFocusLocation;
  bool get pendingOpenHomeSearch => _pendingOpenHomeSearch;

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

  void navigateToHomeSearch() {
    _pendingOpenHomeSearch = true;
    navigateToTab(0);
  }

  void clearPendingHomeSearch() {
    _pendingOpenHomeSearch = false;
  }

  void clearPendingFocusLocation() {
    _pendingFocusLocation = null;
  }

  void clearPendingNavigation() {
    _pendingTabIndex = -1;
    notifyListeners();
  }
}
