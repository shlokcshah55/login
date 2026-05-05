import 'dart:async';

/// Prevents the same navigation (or other async action) from being triggered
/// multiple times concurrently for a given [key].
///
/// This is primarily used to avoid stacking multiple identical routes when a
/// user rapidly taps the same UI element.
class RouteOpenGuard {
  static final Set<String> _openKeys = <String>{};

  static Future<T?> run<T>(String key, Future<T?> Function() action) {
    if (_openKeys.contains(key)) return Future<T?>.value(null);
    _openKeys.add(key);

    try {
      final future = action();
      return future.whenComplete(() {
        _openKeys.remove(key);
      });
    } catch (e, st) {
      _openKeys.remove(key);
      return Future<T?>.error(e, st);
    }
  }
}
