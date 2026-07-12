import 'package:shared_preferences/shared_preferences.dart';

class SocialSharePresentationStore {
  static const _keyPrefix = 'social_share_presented_v1_';
  static const _maxRemembered = 200;

  Future<Set<String>> presentedIds(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList('$_keyPrefix$userId')?.toSet() ?? {};
  }

  Future<void> markPresented(String userId, Iterable<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$userId';
    final merged = <String>{
      ...ids,
      ...?preferences.getStringList(key),
    }.take(_maxRemembered).toList(growable: false);
    await preferences.setStringList(key, merged);
  }
}
