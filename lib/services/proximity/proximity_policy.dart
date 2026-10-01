import 'dart:math' as math;

import 'package:login/services/proximity/proximity_candidate.dart';
import 'package:login/services/proximity/proximity_hours.dart';

/// All tunable numbers for proximity notifications live here.
class ProximityConfig {
  const ProximityConfig({
    this.radiusMeters = 400,
    this.maxPerHour = 2,
    this.maxPerDay = 3,
    this.maxPerEvent = 1,
    this.perPlaceCooldown = const Duration(days: 4),
    this.quietStartHour = 22,
    this.quietEndHour = 8,
    this.closingSoonWindow = const Duration(minutes: 30),
    this.socialBoost = 0.30,
    this.insightWeight = 0.20,
    this.distanceWeight = 0.30,
    this.qualityWeight = 0.20,
  });

  final double radiusMeters;
  final int maxPerHour;
  final int maxPerDay;

  /// How many places one location update may notify about.
  final int maxPerEvent;
  final Duration perPlaceCooldown;

  /// Quiet hours in local time, [start, end). May wrap midnight.
  final int quietStartHour;
  final int quietEndHour;
  final Duration closingSoonWindow;

  final double socialBoost;
  final double insightWeight;
  final double distanceWeight;
  final double qualityWeight;
}

/// What the policy needs to know about notifications already sent.
class ProximityContext {
  const ProximityContext({
    required this.now,
    this.sentTimestamps = const [],
    this.lastSentByLocation = const {},
  });

  final DateTime now;

  /// Times of recent proximity pushes (any place). Older entries are ignored.
  final List<DateTime> sentTimestamps;
  final Map<int, DateTime> lastSentByLocation;
}

enum SuppressReason {
  quietHours,
  hourlyCap,
  dailyCap,
  outOfRadius,
  beenTo,
  cooldown,
  closed,
  closingSoon,
  lowConfidence,
}

class ProximityDecision {
  const ProximityDecision({
    required this.candidate,
    required this.distanceMeters,
    required this.score,
    required this.status,
  });

  final ProximityCandidate candidate;
  final double distanceMeters;
  final double score;
  final OpeningStatus status;
}

class ProximityEvaluation {
  const ProximityEvaluation({
    required this.selected,
    required this.suppressed,
    this.globalReason,
  });

  /// Best-first, already trimmed to the per-event and cap budget.
  final List<ProximityDecision> selected;
  final Map<int, SuppressReason> suppressed;

  /// Set when every candidate was blocked by quiet hours or a cap.
  final SuppressReason? globalReason;
}

class ProximityPolicy {
  const ProximityPolicy([this.config = const ProximityConfig()]);

  final ProximityConfig config;

  /// Decides which of [candidates] (with their current distances in metres)
  /// deserve a push right now.
  ProximityEvaluation evaluate({
    required List<({ProximityCandidate candidate, double distanceMeters})>
        candidates,
    required ProximityContext context,
  }) {
    final global = _globalReason(context);
    if (global != null) {
      return ProximityEvaluation(
        selected: const [],
        suppressed: const {},
        globalReason: global,
      );
    }

    final suppressed = <int, SuppressReason>{};
    final eligible = <ProximityDecision>[];

    for (final entry in candidates) {
      final c = entry.candidate;
      final status = evaluateOpeningStatus(
        now: context.now,
        periods: c.openingHoursPeriods,
        openNow: c.openNow,
        closingSoonWindow: config.closingSoonWindow,
      );
      final reason = _candidateReason(c, entry.distanceMeters, status, context);
      if (reason != null) {
        suppressed[c.locationId] = reason;
        continue;
      }
      eligible.add(ProximityDecision(
        candidate: c,
        distanceMeters: entry.distanceMeters,
        score: score(c, entry.distanceMeters),
        status: status,
      ));
    }

    eligible.sort((a, b) => b.score.compareTo(a.score));

    final budget = math.min(
      config.maxPerEvent,
      math.min(
        config.maxPerHour - _sentWithin(context, const Duration(hours: 1)),
        config.maxPerDay - _sentWithin(context, const Duration(hours: 24)),
      ),
    );
    return ProximityEvaluation(
      selected: eligible.take(math.max(0, budget)).toList(),
      suppressed: suppressed,
    );
  }

  /// 0..1. Higher wins when several places compete for the same push.
  double score(ProximityCandidate c, double distanceMeters) {
    final social = c.isSocial ? 1.0 : 0.0;

    var insight = 0.0;
    if (c.insight.topDish != null) insight += 0.5;
    if (c.insight.creatorHandle != null) insight += 0.3;
    if (c.insight.vibe != null) insight += 0.2;

    final proximity =
        (1 - distanceMeters / config.radiusMeters).clamp(0.0, 1.0);

    // 3.0 stars is neutral-low, 5.0 is full marks. Unknown rating is neutral.
    final quality = c.rating == null
        ? 0.5
        : ((c.rating! - 3.0) / 2.0).clamp(0.0, 1.0).toDouble();

    final total = config.socialBoost * social +
        config.insightWeight * insight +
        config.distanceWeight * proximity +
        config.qualityWeight * quality;
    final maxTotal = config.socialBoost +
        config.insightWeight +
        config.distanceWeight +
        config.qualityWeight;
    return total / maxTotal;
  }

  SuppressReason? _globalReason(ProximityContext context) {
    if (isQuietHour(context.now)) return SuppressReason.quietHours;
    if (_sentWithin(context, const Duration(hours: 24)) >= config.maxPerDay) {
      return SuppressReason.dailyCap;
    }
    if (_sentWithin(context, const Duration(hours: 1)) >= config.maxPerHour) {
      return SuppressReason.hourlyCap;
    }
    return null;
  }

  SuppressReason? _candidateReason(
    ProximityCandidate c,
    double distanceMeters,
    OpeningStatus status,
    ProximityContext context,
  ) {
    if (distanceMeters > config.radiusMeters) return SuppressReason.outOfRadius;

    final standing = _standingReason(c, context);
    if (standing != null) return standing;

    if (status.state == OpenState.closed) return SuppressReason.closed;
    if (status.state == OpenState.closingSoon) {
      return SuppressReason.closingSoon;
    }
    return null;
  }

  /// Reasons that hold regardless of where the user is or what time it is.
  SuppressReason? _standingReason(
    ProximityCandidate c,
    ProximityContext context,
  ) {
    if (c.insight.beenTo) return SuppressReason.beenTo;

    final lastSent = context.lastSentByLocation[c.locationId];
    if (lastSent != null &&
        context.now.difference(lastSent) < config.perPlaceCooldown) {
      return SuppressReason.cooldown;
    }

    // Shares the extractor was unsure about only count once the user has
    // confirmed them. Unknown tier (legacy saves) is allowed.
    if (c.isSocial) {
      final tier = c.insight.confidenceTier;
      if (tier != null && tier != 'high' && !c.insight.confirmedByUser) {
        return SuppressReason.lowConfidence;
      }
    }
    return null;
  }

  /// False for places that cannot notify right now no matter where the user
  /// goes (been-to, cooling down, unconfirmed low-confidence share). Used to
  /// avoid spending scarce OS geofence slots on them.
  bool isWorthMonitoring(ProximityCandidate c, ProximityContext context) =>
      _standingReason(c, context) == null;

  bool isQuietHour(DateTime now) {
    final start = config.quietStartHour;
    final end = config.quietEndHour;
    if (start == end) return false;
    final h = now.hour;
    return start < end ? (h >= start && h < end) : (h >= start || h < end);
  }

  int _sentWithin(ProximityContext context, Duration window) {
    return context.sentTimestamps
        .where((t) => context.now.difference(t) < window)
        .length;
  }
}
