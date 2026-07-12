import 'package:flutter/foundation.dart';

/// Tracks whether the full notifications surface is currently visible.
///
/// A counter keeps nested or overlapping notification routes from marking the
/// surface hidden until the final route has closed.
class NotificationSurfaceVisibility {
  NotificationSurfaceVisibility._();

  static final NotificationSurfaceVisibility instance =
      NotificationSurfaceVisibility._();

  final ValueNotifier<bool> visible = ValueNotifier<bool>(false);
  int _visibleRoutes = 0;

  void enter() {
    _visibleRoutes += 1;
    visible.value = true;
  }

  void exit() {
    if (_visibleRoutes > 0) _visibleRoutes -= 1;
    visible.value = _visibleRoutes > 0;
  }
}
