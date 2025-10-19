import 'package:flutter/material.dart';
import 'package:login/api/models/locations.dart';

enum NavState { standard, dynamic }

class DynamicNavProvider with ChangeNotifier {
  NavState _navState = NavState.standard;
  LocationModel? _selectedLocation;

  NavState get navState => _navState;
  LocationModel? get selectedLocation => _selectedLocation;

  void showDynamicNav(LocationModel location) {
    _navState = NavState.dynamic;
    _selectedLocation = location;
    notifyListeners();
  }

  void showStandardNav() {
    _navState = NavState.standard;
    _selectedLocation = null;
    notifyListeners();
  }
}
