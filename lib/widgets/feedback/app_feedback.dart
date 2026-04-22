import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'error_popover.dart';

class AppFeedback {
  static const String _genericSorryMessage =
      'We’re working hard to fix this — sorry.';

  static String _sanitizeForUser(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return _genericSorryMessage;

    final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    final looksLikeLog = trimmed.contains('\n') ||
        trimmed.length > 160 ||
        RegExp(r'\b(StackTrace|Exception|Error:|at\s+|dart:|flutter:)\b')
            .hasMatch(trimmed) ||
        RegExp(r'[{}[\]]').hasMatch(trimmed);

    if (looksLikeLog) return _genericSorryMessage;

    if (normalized.length <= 120) return normalized;
    return '${normalized.substring(0, 117)}…';
  }

  static Future<void> showError(
    BuildContext context, {
    String title = 'Something went wrong',
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    if (!context.mounted) return;

    if (kDebugMode) {
      debugPrint('[AppFeedback.showError] $title: $message');
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) {
        return ErrorPopover(
          title: title,
          message: _sanitizeForUser(message),
          primaryActionLabel: actionLabel,
          onPrimaryAction: onAction,
        );
      },
      transitionBuilder: (dialogContext, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    Widget? leading,
    Duration duration = const Duration(seconds: 2),
  }) {
    // Intentionally noop: the product does not show success snackbars.
    // Keeping the API prevents having to chase call sites.
    return;
  }
}
