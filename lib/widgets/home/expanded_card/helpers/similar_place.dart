import 'package:login/models/locations.dart';

/// A location ranked by vibe similarity to the source location.
class SimilarPlace {
  final LocationModel location;

  /// Cosine similarity (0.0–1.0) to the source location.
  final double similarity;

  /// Vibe tags shared between both locations (for display).
  final List<String> sharedVibes;

  const SimilarPlace({
    required this.location,
    required this.similarity,
    this.sharedVibes = const [],
  });
}
