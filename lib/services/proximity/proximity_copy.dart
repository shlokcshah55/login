import 'package:login/services/proximity/proximity_hours.dart';
import 'package:login/services/proximity/proximity_policy.dart';

class ProximityMessage {
  const ProximityMessage({
    required this.title,
    required this.body,
    required this.metadata,
  });

  final String title;
  final String body;

  /// String-only so it can ride straight through `send-notification`.
  final Map<String, String> metadata;
}

/// Builds the push copy. Leads with the creator's reason for social saves and
/// degrades to place facts when that data is missing.
ProximityMessage buildProximityMessage(ProximityDecision decision) {
  final c = decision.candidate;
  final insight = c.insight;
  final distance = formatDistance(decision.distanceMeters);
  final closes = _closesSuffix(decision.status);

  final creator = insight.creatorHandle == null
      ? null
      : (insight.creatorHandle!.startsWith('@')
          ? insight.creatorHandle!
          : '@${insight.creatorHandle!}');

  late final String title;
  late final String body;

  if (c.isSocial && creator != null) {
    title = "$creator's pick is nearby";
    if (insight.topDish != null) {
      body = 'Try the ${insight.topDish} at ${c.name} · $distance away$closes';
    } else if (insight.vibe != null) {
      body = '${c.name} · ${insight.vibe} · $distance away$closes';
    } else {
      body = '${c.name} is $distance away$closes';
    }
  } else if (c.isSocial) {
    title = 'Saved from ${c.source.label} nearby';
    body = insight.topDish != null
        ? 'Try the ${insight.topDish} at ${c.name} · $distance away$closes'
        : '${c.name} is $distance away$closes';
  } else {
    title = 'Saved place nearby';
    final facts = <String>[
      c.name,
      if (c.cuisine != null && c.cuisine!.trim().isNotEmpty) c.cuisine!.trim(),
      if (c.rating != null) '${c.rating!.toStringAsFixed(1)}★',
    ];
    body = '${facts.join(' · ')} — $distance away$closes';
  }

  return ProximityMessage(
    title: title,
    body: body,
    metadata: {
      'locationId': c.locationId.toString(),
      'locationName': c.name,
      'distanceMeters': decision.distanceMeters.round().toString(),
      'savedMethod': c.source.name,
      if (creator != null) 'creatorHandle': creator,
      if (insight.topDish != null) 'dish': insight.topDish!,
      if (decision.status.closesAt != null)
        'closesAt': decision.status.closesAt!.toIso8601String(),
    },
  );
}

/// "300m" under a kilometre (rounded to 10), otherwise "1.2km".
String formatDistance(double meters) {
  if (meters < 1000) {
    final rounded = (meters / 10).round() * 10;
    return '${rounded < 10 ? 10 : rounded}m';
  }
  final km = meters / 1000;
  final text = km.toStringAsFixed(1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}km';
}

/// " · open till 11pm", only when the place is open with a known close time.
String _closesSuffix(OpeningStatus status) {
  final closesAt = status.closesAt;
  if (status.state != OpenState.open || closesAt == null) return '';
  return ' · open till ${formatClockTime(closesAt)}';
}

String formatClockTime(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final suffix = time.hour < 12 ? 'am' : 'pm';
  final minutes =
      time.minute == 0 ? '' : ':${time.minute.toString().padLeft(2, '0')}';
  return '$hour12$minutes$suffix';
}
