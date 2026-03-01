import 'package:shared_preferences/shared_preferences.dart';

/// Shared cap/cooldown logic for proximity notifications.
/// - Max 3 notifications per day
/// - 4-hour cooldown per location
class ProximityNotificationGate {
  static final ProximityNotificationGate _instance =
      ProximityNotificationGate._internal();
  factory ProximityNotificationGate() => _instance;
  ProximityNotificationGate._internal();

  static const int _dailyCap = 3;
  static const Duration _locationCooldown = Duration(hours: 4);

  static const String _keyDailyCount = 'prox_daily_count';
  static const String _keyDailyDate = 'prox_daily_date';
  static const String _keyCooldownPrefix = 'prox_cooldown_';

  /// Check if we can send a notification for [locationId].
  /// Returns true if daily cap not reached AND location cooldown has expired.
  Future<bool> canNotify(int locationId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();

    // Reset daily count if date changed
    final storedDate = prefs.getString(_keyDailyDate);
    if (storedDate != today) {
      await prefs.setInt(_keyDailyCount, 0);
      await prefs.setString(_keyDailyDate, today);
    }

    // Check daily cap
    final dailyCount = prefs.getInt(_keyDailyCount) ?? 0;
    if (dailyCount >= _dailyCap) return false;

    // Check per-location cooldown
    final lastNotified = prefs.getInt('$_keyCooldownPrefix$locationId');
    if (lastNotified != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastNotified;
      if (elapsed < _locationCooldown.inMilliseconds) return false;
    }

    return true;
  }

  /// Record that a notification was sent for [locationId].
  Future<void> recordNotification(int locationId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();

    // Ensure date is current
    final storedDate = prefs.getString(_keyDailyDate);
    if (storedDate != today) {
      await prefs.setInt(_keyDailyCount, 0);
      await prefs.setString(_keyDailyDate, today);
    }

    final dailyCount = prefs.getInt(_keyDailyCount) ?? 0;
    await prefs.setInt(_keyDailyCount, dailyCount + 1);
    await prefs.setInt(
      '$_keyCooldownPrefix$locationId',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
