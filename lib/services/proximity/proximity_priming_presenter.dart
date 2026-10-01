import 'package:flutter/widgets.dart';
import 'package:login/app/app_root.dart' show navigatorKey;
import 'package:login/widgets/proximity_priming_sheet.dart';

/// Shows the explainer if the app is on screen. Returns:
///  * true when the user wants nudges on,
///  * false when they decline or dismiss,
///  * null when it could not be shown now (backgrounded, no navigator yet),
///    so the caller keeps the request pending for a later moment.
Future<bool?> presentProximityPriming() async {
  // Let the screen the user just landed on settle before covering it.
  await Future<void>.delayed(const Duration(seconds: 2));

  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
    return null;
  }

  // The Navigator's own context sits above itself, so use its overlay's.
  final overlayContext = navigatorKey.currentState?.overlay?.context;
  if (overlayContext == null || !overlayContext.mounted) return null;

  final accepted = await showProximityPrimingSheet(overlayContext);
  return accepted ?? false;
}
