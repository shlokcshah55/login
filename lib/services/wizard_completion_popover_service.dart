import 'package:login/supabase/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WizardCompletionPopoverService {
  static const Duration _cooldown = Duration(days: 4);
  static const String _lastShownAtKey = 'wizard_completion_popover_last_shown_at';

  Future<bool> shouldShowNow() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scopedKey(userId, _lastShownAtKey));
    final lastShownAtUtc = raw == null ? null : DateTime.tryParse(raw)?.toUtc();
    if (lastShownAtUtc == null) return true;
    final nowUtc = DateTime.now().toUtc();
    return nowUtc.difference(lastShownAtUtc) >= _cooldown;
  }

  Future<void> markShownNow() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey(userId, _lastShownAtKey),
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  String _scopedKey(String userId, String key) => '${key}_$userId';
}

