import 'dart:convert';

import 'package:login/services/proximity/proximity_geofence_bridge.dart';

/// How often we have asked the user to turn on background nudges.
class AlwaysPromptHistory {
  const AlwaysPromptHistory({this.count = 0, this.lastAskedAt});

  final int count;
  final DateTime? lastAskedAt;

  AlwaysPromptHistory asked(DateTime now) =>
      AlwaysPromptHistory(count: count + 1, lastAskedAt: now);

  String encode() => jsonEncode({
        'count': count,
        'last': lastAskedAt?.toIso8601String(),
      });

  static AlwaysPromptHistory decode(String? raw) {
    if (raw == null) return const AlwaysPromptHistory();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AlwaysPromptHistory(
        count: (map['count'] as num?)?.toInt() ?? 0,
        lastAskedAt: DateTime.tryParse('${map['last']}'),
      );
    } catch (_) {
      return const AlwaysPromptHistory();
    }
  }
}

/// Rules for when to show our own explainer before the one-shot iOS
/// "Always" upgrade prompt. The system only ever shows that prompt once, so
/// we spend it carefully: right after the user's first social save, never
/// nagging.
class AlwaysPromptPolicy {
  const AlwaysPromptPolicy({
    this.maxAsks = 2,
    this.minGapBetweenAsks = const Duration(days: 14),
  });

  final int maxAsks;
  final Duration minGapBetweenAsks;

  bool shouldPrompt({
    required LocationAuthStatus status,
    required bool hasPendingSocialSave,
    required AlwaysPromptHistory history,
    required DateTime now,
  }) {
    if (!hasPendingSocialSave) return false;

    // Always can only be requested once While Using has been granted. Before
    // that, the map's own flow asks for basic access first.
    if (status != LocationAuthStatus.whenInUse) return false;

    if (history.count >= maxAsks) return false;
    final last = history.lastAskedAt;
    if (last != null && now.difference(last) < minGapBetweenAsks) return false;
    return true;
  }
}
