import 'package:shared_preferences/shared_preferences.dart';

/// Remembers that a user created an account but never finished onboarding, so
/// the next launch can re-open the post-account steps exactly once.
class OnboardingResumeService {
  static const String _prefix = 'onboarding_in_progress_';

  // True once onboarding was started in this app session. AuthHandler sits
  // underneath the wizard and rebuilds on auth changes, so without this it
  // would "resume" the flow the user is already in.
  static bool _startedThisSession = false;

  Future<void> markInProgress(String userId) async {
    _startedThisSession = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$userId', true);
  }

  Future<void> clear(String userId) async {
    _startedThisSession = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$userId');
  }

  /// True at most once per marked user: reading the flag clears it, so an
  /// abandoned resume falls back to the existing home popover.
  Future<bool> consume(String userId) async {
    if (_startedThisSession) return false;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$userId';
    final pending = prefs.getBool(key) ?? false;
    if (pending) await prefs.remove(key);
    return pending;
  }
}
