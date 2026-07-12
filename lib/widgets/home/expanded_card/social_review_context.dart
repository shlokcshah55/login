import 'package:flutter/foundation.dart';

/// Optional social-extraction metadata and review actions for an expanded
/// restaurant card. Normal expanded-card callers leave this null.
class SocialReviewContext {
  const SocialReviewContext({
    required this.platform,
    required this.placeName,
    this.confidenceScore,
    this.confidenceTier,
    this.onConfirm,
    this.onCorrect,
    this.onRemove,
  });

  final String platform;
  final String placeName;
  final double? confidenceScore;
  final String? confidenceTier;
  final VoidCallback? onConfirm;
  final VoidCallback? onCorrect;
  final VoidCallback? onRemove;
}
