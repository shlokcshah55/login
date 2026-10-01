/// One server-ranked tile candidate from the `get_home_rail` RPC.
///
/// [kind] is `cuisine` (area-lifted and/or personal) or `bubble`. [score] is
/// only comparable within a kind. [locationIds] are best-first and capped at
/// 20 server-side.
class HomeRailCandidate {
  final String kind;
  final String id;
  final String label;
  final double score;
  final int placeCount;
  final List<int> locationIds;

  /// `area`, `personal`, `area+personal` or `bubble`.
  final String reason;

  const HomeRailCandidate({
    required this.kind,
    required this.id,
    required this.label,
    required this.score,
    required this.placeCount,
    required this.locationIds,
    required this.reason,
  });

  static const String kindCuisine = 'cuisine';
  static const String kindBubble = 'bubble';

  bool get isCuisine => kind == kindCuisine;
  bool get isBubble => kind == kindBubble;
  bool get isAreaLifted => reason == 'area' || reason == 'area+personal';

  /// Returns null for malformed rows so one bad row can't drop the rail.
  static HomeRailCandidate? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'];
    final id = raw['id'];
    final label = raw['label'];
    if (kind is! String || id is! String || label is! String) return null;
    final ids = raw['location_ids'];
    return HomeRailCandidate(
      kind: kind,
      id: id,
      label: label,
      score: (raw['score'] as num?)?.toDouble() ?? 0,
      placeCount: (raw['place_count'] as num?)?.toInt() ?? 0,
      locationIds: ids is List
          ? ids.whereType<num>().map((n) => n.toInt()).toList(growable: false)
          : const <int>[],
      reason: raw['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'id': id,
        'label': label,
        'score': score,
        'place_count': placeCount,
        'location_ids': locationIds,
        'reason': reason,
      };
}
