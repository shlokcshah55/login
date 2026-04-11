import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';

/// Result of evaluating a location's fit against the current user's
/// taste affinities. Used by the match banner section.
class MatchResult {
  /// 0.0–1.0 normalised match score.
  final double score;

  /// Human-friendly percentage (0–100).
  int get percent => (score * 100).round();

  /// Top vibe tags that contributed most to the match.
  final List<MapEntry<String, double>> topContributors;

  /// Dietary match ratio (0.0–1.0). null when no dietary data.
  final double? dietaryMatch;

  const MatchResult({
    required this.score,
    this.topContributors = const [],
    this.dietaryMatch,
  });

  String get label {
    if (score >= 0.80) return 'Perfect match';
    if (score >= 0.60) return 'Great match';
    if (score >= 0.40) return 'Good match';
    if (score >= 0.20) return 'Okay match';
    return 'New vibe';
  }

  Color get color {
    if (score >= 0.80) return const Color(0xFF10B981);
    if (score >= 0.60) return const Color(0xFF3B82F6);
    if (score >= 0.40) return const Color(0xFFF59E0B);
    if (score >= 0.20) return const Color(0xFFF97316);
    return const Color(0xFF8B5CF6);
  }
}

/// Builds a [MatchResult] from raw model data.
///
/// Uses the pre-calculated [matchScore] from `LocationModel` directly,
/// then computes the top contributing vibe tags + dietary fit ratio
/// locally for display purposes.
MatchResult buildMatchResult({
  required double? matchScore,
  required VibeVector? locationVibe,
  required List<int>? userVibeAffinity,
  required List<int>? locationDietary,
  required List<int>? userDietary,
}) {
  final score = (matchScore ?? 0.0).clamp(0.0, 1.0);

  final contributors = <MapEntry<String, double>>[];
  double? dietaryMatch;

  // Calculate contributors for display (vibe-based)
  if (locationVibe != null &&
      locationVibe.values.isNotEmpty &&
      userVibeAffinity != null &&
      userVibeAffinity.isNotEmpty) {
    final locVals = locationVibe.values;
    final int len = math.min(locVals.length, userVibeAffinity.length);

    // Find top contributors: element-wise product, sorted descending.
    for (int i = 0; i < len && i < vibeTagsByIndex.length; i++) {
      final contribution = locVals[i] * userVibeAffinity[i].toDouble();
      if (contribution > 0) {
        contributors.add(MapEntry(vibeTagsByIndex[i], contribution));
      }
    }
    contributors.sort((a, b) => b.value.compareTo(a.value));
  }

  // Calculate dietary match for display
  if (locationDietary != null &&
      locationDietary.isNotEmpty &&
      userDietary != null &&
      userDietary.isNotEmpty) {
    final int len = math.min(locationDietary.length, userDietary.length);
    int matched = 0;
    int required = 0;
    for (int i = 0; i < len; i++) {
      if (userDietary[i] == 1) {
        required++;
        if (locationDietary[i] == 1) matched++;
      }
    }
    dietaryMatch = required > 0 ? matched / required : 1.0;
  }

  return MatchResult(
    score: score,
    topContributors: contributors.take(5).toList(),
    dietaryMatch: dietaryMatch,
  );
}
