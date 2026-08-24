import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';

class NavigationProvider with ChangeNotifier {
  int _pendingTabIndex = -1;
  LocationModel? _pendingFocusLocation;
  bool _pendingOpenHomeSearch = false;
  String? _pendingShowCollectionId;
  bool _pendingOpenCollectionList = false;
  int _unreadBubbleCount = 0;

  int get pendingTabIndex => _pendingTabIndex;
  bool get hasPendingNavigation => _pendingTabIndex >= 0;
  LocationModel? get pendingFocusLocation => _pendingFocusLocation;
  bool get pendingOpenHomeSearch => _pendingOpenHomeSearch;
  String? get pendingShowCollectionId => _pendingShowCollectionId;
  bool get pendingOpenCollectionList => _pendingOpenCollectionList;
  int get unreadBubbleCount => _unreadBubbleCount;

  void setUnreadBubbleCount(int count) {
    if (_unreadBubbleCount == count) return;
    _unreadBubbleCount = count;
    notifyListeners();
  }

  void navigateToTab(int tabIndex) {
    if (tabIndex < 0 || tabIndex > 2) {
      throw ArgumentError('Tab index must be 0, 1, or 2');
    }
    _pendingTabIndex = tabIndex;
    notifyListeners();
  }

  void navigateToLocationOnMap(LocationModel location) {
    _pendingFocusLocation = location;
    navigateToTab(0);
  }

  void navigateToCollectionOnMap(String collectionId) {
    _pendingShowCollectionId = collectionId;
    _pendingOpenCollectionList = true;
    navigateToTab(0);
  }

  void navigateToCollectionMapOnly(String collectionId) {
    _pendingShowCollectionId = collectionId;
    _pendingOpenCollectionList = false;
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

  void clearPendingShowCollectionId() {
    _pendingShowCollectionId = null;
    _pendingOpenCollectionList = false;
  }

  void clearPendingNavigation() {
    _pendingTabIndex = -1;
    notifyListeners();
  }
}
