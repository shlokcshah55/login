import 'package:shared_preferences/shared_preferences.dart';

class ReferralPromptService {
  static const String _pendingKey = 'referral_prompt_pending';
  static const String _handledKey = 'referral_prompt_handled';

  Future<void> markPendingForUser(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(userId, _pendingKey), true);
  }

  Future<bool> shouldShowForUser(String? userId) async {
    if (userId == null || userId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_scopedKey(userId, _pendingKey)) ?? false;
    final handled = prefs.getBool(_scopedKey(userId, _handledKey)) ?? false;
    return pending && !handled;
  }

  Future<void> markHandledForUser(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(userId, _handledKey), true);
    await prefs.remove(_scopedKey(userId, _pendingKey));
  }

  String _scopedKey(String userId, String key) => '${key}_$userId';
}
