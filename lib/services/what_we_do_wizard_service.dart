import 'package:login/supabase/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhatWeDoWizardService {
  static const String _pendingKey = 'what_we_do_wizard_pending';
  static const String _seenKey = 'what_we_do_wizard_seen';
  static const bool _previewAlwaysShow =
      bool.fromEnvironment('PREVIEW_WHAT_WE_DO_WIZARD', defaultValue: false);

  Future<void> markPending() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(userId, _pendingKey), true);
  }

  Future<bool> shouldShowNow() async {
    if (_previewAlwaysShow) return true;
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final pendingKey = _scopedKey(userId, _pendingKey);
    final seenKey = _scopedKey(userId, _seenKey);
    final pending = prefs.getBool(pendingKey) ?? false;
    final seen = prefs.getBool(seenKey) ?? false;

    return pending || !seen;
  }

  Future<bool> hasSeen() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey(userId, _seenKey)) ?? false;
  }

  Future<void> markCompleted() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(userId, _pendingKey), false);
    await prefs.setBool(_scopedKey(userId, _seenKey), true);
  }

  String _scopedKey(String userId, String key) => '${key}_$userId';
}
