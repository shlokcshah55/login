import 'package:flutter/widgets.dart';
import 'package:login/models/locations.dart';

/// The kind of slice a [HomeCategory] represents. Drives the tile's icon
/// treatment and how its focused list is resolved.
enum HomeCategoryKind { source, cuisine, vibe, eatList }

/// A single tile in the home category carousel. Tapping it drills into a
/// focused carousel of the locations returned by [resolve].
///
/// Categories are generated dynamically and are area-/user-aware, so the set
/// varies as the map moves and the user's taste profile changes.
class HomeCategory {
  final HomeCategoryKind kind;

  /// Stable identifier within a kind — e.g. 'instagram' / 'tiktok' for
  /// sources, a cuisine key like 'indian', a vibe key like 'cozy', or a
  /// collectionId for eat-lists. Used for equality / carousel keys.
  final String id;

  /// Human-readable label shown on the tile.
  final String label;

  /// Icon for source/vibe tiles (null when [emoji] is used instead).
  final IconData? icon;

  /// Emoji for eat-lists / cuisines (null when [icon] is used instead).
  final String? emoji;

  /// Number of spots available for this category — shown on the tile and
  /// used by the builder to hide empty categories.
  final int count;

  /// Lazily produces the focused location list when the tile is tapped.
  final Future<List<LocationModel>> Function() resolve;

  const HomeCategory({
    required this.kind,
    required this.id,
    required this.label,
    required this.count,
    required this.resolve,
    this.icon,
    this.emoji,
  });

  @override
  bool operator ==(Object other) =>
      other is HomeCategory && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}
