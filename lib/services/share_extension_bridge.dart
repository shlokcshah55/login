import 'package:flutter/services.dart';
import 'package:login/supabase/supabase_client.dart';

/// Native side of the iOS share extension. The extension reads the signed-in
/// user id from an App Group, which `AppRoot` already writes on every auth
/// change. Onboarding re-syncs it explicitly so the first share from TikTok
/// is attributed even if the user leaves the app immediately after sign-up.
class ShareExtensionBridge {
  ShareExtensionBridge._();

  static const MethodChannel _channel =
      MethodChannel('com.example.srishlok.pinit/share');

  /// Returns true when the id was written (always false off iOS).
  static Future<bool> syncUserId() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return false;
    try {
      await _channel.invokeMethod('saveUserId', {'userId': userId});
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
