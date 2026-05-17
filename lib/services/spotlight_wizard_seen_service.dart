import 'package:login/supabase/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpotlightWizardSeenService {
  SpotlightWizardSeenService(this.id);

  final String id;

  static const bool _previewAll =
      bool.fromEnvironment('PREVIEW_SPOTLIGHT_WIZARDS', defaultValue: false);

  Future<bool> shouldShowNow() async {
    if (_previewAll) return true;
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_scopedKey(userId)) ?? false);
  }

  Future<void> markCompleted() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(userId), true);
  }

  String _scopedKey(String userId) => 'spotlight_wizard_seen_${id}_$userId';
}
