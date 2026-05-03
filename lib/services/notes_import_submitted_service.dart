import 'package:login/supabase/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotesImportSubmittedService {
  static const String _key = 'notes_import_submitted';

  Future<bool> hasBeenSubmitted() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey(userId)) ?? false;
  }

  Future<void> markSubmitted() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(userId), true);
  }

  String _scopedKey(String userId) => '${_key}_$userId';
}
