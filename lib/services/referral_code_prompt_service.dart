import 'package:login/supabase/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReferralCodePromptService {
  ReferralCodePromptService({String? Function()? currentUserId})
      : _currentUserId =
            currentUserId ?? (() => SupabaseClientManager().currentUser?.id);

  static const String _pendingKey = 'referral_code_prompt_pending';
  static const String _completedKey = 'referral_code_prompt_completed';

  final String? Function() _currentUserId;

  Future<void> markPending() async {
    final userId = _currentUserId();
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(userId, _pendingKey), true);
    await prefs.setBool(_scopedKey(userId, _completedKey), false);
  }

  Future<bool> shouldShowNow() async {
    final userId = _currentUserId();
    if (userId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(_scopedKey(userId, _pendingKey)) ?? false;
    final completed = prefs.getBool(_scopedKey(userId, _completedKey)) ?? false;

    return pending && !completed;
  }

  Future<void> markCompleted() async {
    final userId = _currentUserId();
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(userId, _pendingKey), false);
    await prefs.setBool(_scopedKey(userId, _completedKey), true);
  }

  String _scopedKey(String userId, String key) => '${key}_$userId';
}
