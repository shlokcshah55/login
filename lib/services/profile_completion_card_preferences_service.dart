import 'package:shared_preferences/shared_preferences.dart';

class ProfileCompletionCardPreferencesService {
  static const String _collapsedKey = 'profile_completion_card_collapsed';

  Future<bool> isCollapsed({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey(userId, _collapsedKey)) ?? false;
  }

  Future<void> setCollapsed({
    required String userId,
    required bool collapsed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(userId, _collapsedKey), collapsed);
  }

  String _scopedKey(String userId, String key) => '${key}_$userId';
}
