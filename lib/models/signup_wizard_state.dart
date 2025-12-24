import 'package:flutter/foundation.dart';

/// Manages the state for the signup wizard flow
class SignupWizardState extends ChangeNotifier {
  // Step 1: Account Info
  String? _userId;
  String _name = '';
  String _email = '';
  String? _profilePictureUrl;

  // Step 2: Dietary Preferences
  List<String> _selectedDietaryTagIds = [];
  int _spiceTolerance = 3; // Default to middle value

  // Step 3: Vibe Selection
  List<String> _selectedVibeTagIds = [];

  // Step 4: Restaurant Swipes
  Map<int, bool> _restaurantDecisions = {}; // locationId -> saved (true) or passed (false)

  // Getters
  String? get userId => _userId;
  String get name => _name;
  String get email => _email;
  String? get profilePictureUrl => _profilePictureUrl;
  List<String> get selectedDietaryTagIds => List.unmodifiable(_selectedDietaryTagIds);
  int get spiceTolerance => _spiceTolerance;
  List<String> get selectedVibeTagIds => List.unmodifiable(_selectedVibeTagIds);
  Map<int, bool> get restaurantDecisions => Map.unmodifiable(_restaurantDecisions);

  // Get list of restaurant IDs that were saved
  List<int> get savedRestaurantIds {
    return _restaurantDecisions.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
  }

  // Setters
  void setUserId(String userId) {
    _userId = userId;
    notifyListeners();
  }

  void setAccountInfo(String name, String email) {
    _name = name;
    _email = email;
    notifyListeners();
  }

  void setProfilePicture(String? url) {
    _profilePictureUrl = url;
    notifyListeners();
  }

  void setSpiceTolerance(int level) {
    if (level < 1 || level > 5) {
      throw ArgumentError('Spice tolerance must be between 1 and 5');
    }
    _spiceTolerance = level;
    notifyListeners();
  }

  void toggleDietaryTag(String tagId) {
    if (_selectedDietaryTagIds.contains(tagId)) {
      _selectedDietaryTagIds.remove(tagId);
    } else {
      _selectedDietaryTagIds.add(tagId);
    }
    notifyListeners();
  }

  void setDietaryTags(List<String> tagIds) {
    _selectedDietaryTagIds = List.from(tagIds);
    notifyListeners();
  }

  void toggleVibeTag(String tagId) {
    if (_selectedVibeTagIds.contains(tagId)) {
      _selectedVibeTagIds.remove(tagId);
    } else {
      // Max 10 vibe tags
      if (_selectedVibeTagIds.length < 10) {
        _selectedVibeTagIds.add(tagId);
      }
    }
    notifyListeners();
  }

  void setVibeTags(List<String> tagIds) {
    if (tagIds.length > 10) {
      throw ArgumentError('Cannot select more than 10 vibe tags');
    }
    _selectedVibeTagIds = List.from(tagIds);
    notifyListeners();
  }

  bool canAddMoreVibeTags() {
    return _selectedVibeTagIds.length < 10;
  }

  // Record a restaurant decision: true = saved, false = passed
  void recordRestaurantDecision(int locationId, bool liked) {
    _restaurantDecisions[locationId] = liked;
    notifyListeners();
  }

  // Validation
  bool isStep1Valid() {
    return _name.isNotEmpty && _email.isNotEmpty && _userId != null;
  }

  bool isStep2Valid() {
    // Dietary tags and spice tolerance are optional, but we want at least one piece of info
    return true; // Always valid, these are preferences
  }

  bool isStep3Valid() {
    // At least one vibe tag recommended, but not required
    return _selectedVibeTagIds.isNotEmpty;
  }

  bool isStep4Valid() {
    // Restaurant swipes are optional
    return true;
  }

  // Reset state
  void reset() {
    _userId = null;
    _name = '';
    _email = '';
    _profilePictureUrl = null;
    _selectedDietaryTagIds.clear();
    _spiceTolerance = 3;
    _selectedVibeTagIds.clear();
    _restaurantDecisions.clear();
    notifyListeners();
  }
}
