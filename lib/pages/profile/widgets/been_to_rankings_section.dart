import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/been_to_rankings_events.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/utils/route_open_guard.dart';
import 'package:login/widgets/home/expanded_location_card.dart';

import 'pinit_colors.dart';

class BeenToRankingsSection extends StatefulWidget {
  final String userId;
  final bool showGateKeepToggle;
  final bool allowExpand;
  final int maxPlaces;
  final int collapsedPlacesCount;
  final List<BeenToRankedPlaceSeed>? seededPlaces;

  const BeenToRankingsSection({
    super.key,
    required this.userId,
    this.showGateKeepToggle = true,
    this.allowExpand = true,
    this.maxPlaces = 15,
    this.collapsedPlacesCount = 3,
    this.seededPlaces,
  });

  @override
  State<BeenToRankingsSection> createState() => _BeenToRankingsSectionState();
}

class _BeenToRankingsSectionState extends State<BeenToRankingsSection> {
  Future<List<_RankedPlace>>? _future;
  late int _visibleCount;
  bool _gateKeep = false;
  bool _isUpdatingGateKeep = false;
  bool _hasLoadedGateKeepState = false;
  String? _beenToCollectionId;
  String? _beenToCollectionName;
  String? _beenToCoverColor;
  StreamSubscription<String>? _rankingsSub;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.collapsedPlacesCount;
    if (widget.showGateKeepToggle) {
      unawaited(_loadGateKeepState());
    }
    _future = widget.seededPlaces == null
        ? _fetchTopRatedPlaces()
        : Future<List<_RankedPlace>>.value(
            widget.seededPlaces!
                .map(
                  (seed) => _RankedPlace(
                    rank: seed.rank,
                    location: seed.location,
                    userRating: seed.userRating,
                  ),
                )
                .toList(growable: false),
          );
    _rankingsSub = BeenToRankingsEvents.instance.changes.listen((userId) {
      if (!mounted) return;
      if (userId != widget.userId) return;
      setState(() {
        _visibleCount = widget.collapsedPlacesCount;
        _future = widget.seededPlaces == null
            ? _fetchTopRatedPlaces()
            : Future<List<_RankedPlace>>.value(
                widget.seededPlaces!
                    .map(
                      (seed) => _RankedPlace(
                        rank: seed.rank,
                        location: seed.location,
                        userRating: seed.userRating,
                      ),
                    )
                    .toList(growable: false),
              );
      });
    });
  }

  @override
  void dispose() {
    _rankingsSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BeenToRankingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.seededPlaces != widget.seededPlaces ||
        oldWidget.collapsedPlacesCount != widget.collapsedPlacesCount) {
      _visibleCount = widget.collapsedPlacesCount;
      _future = widget.seededPlaces == null
          ? _fetchTopRatedPlaces()
          : Future<List<_RankedPlace>>.value(
              widget.seededPlaces!
                  .map(
                    (seed) => _RankedPlace(
                      rank: seed.rank,
                      location: seed.location,
                      userRating: seed.userRating,
                    ),
                  )
                  .toList(growable: false),
            );
    }

    if (widget.showGateKeepToggle && oldWidget.userId != widget.userId) {
      _hasLoadedGateKeepState = false;
      _beenToCollectionId = null;
      _beenToCollectionName = null;
      _beenToCoverColor = null;
      unawaited(_loadGateKeepState());
    }
  }

  Future<void> _loadGateKeepState() async {
    if (_hasLoadedGateKeepState) return;
    _hasLoadedGateKeepState = true;

    try {
      final service = SupabaseService();
      final collectionId = await service.reviews.getOrCreateBeenToCollection();
      if (!mounted) return;
      if (collectionId == null) return;

      final row = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableCollections)
          .select(
            '${SupabaseConstants.columnName},'
            '${SupabaseConstants.columnCoverColor},'
            '${SupabaseConstants.columnIsPublic}',
          )
          .eq(SupabaseConstants.columnCollectionId, collectionId)
          .single();

      final isPublic = row[SupabaseConstants.columnIsPublic] as bool? ?? true;
      setState(() {
        _beenToCollectionId = collectionId;
        _beenToCollectionName =
            row[SupabaseConstants.columnName] as String? ?? 'Been To';
        _beenToCoverColor = row[SupabaseConstants.columnCoverColor] as String?;
        _gateKeep = !isPublic;
      });
    } catch (_) {
      // Best-effort: keep the UI usable even if this query fails.
    }
  }

  Future<void> _setGateKeep(bool next) async {
    if (!widget.showGateKeepToggle) return;
    if (_isUpdatingGateKeep) return;

    final collectionId = _beenToCollectionId;
    final name = _beenToCollectionName;
    if (collectionId == null || name == null) {
      unawaited(_loadGateKeepState());
      return;
    }

    final prev = _gateKeep;
    setState(() {
      _gateKeep = next;
      _isUpdatingGateKeep = true;
    });

    try {
      await SupabaseService().collections.updateCollection(
            collectionId: collectionId,
            name: name,
            coverColor: _beenToCoverColor,
            isPublic: !next,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gateKeep = prev;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isUpdatingGateKeep = false;
      });
    }
  }

  Future<List<_RankedPlace>> _fetchTopRatedPlaces() async {
    final service = SupabaseService();
    final raw =
        await service.reviews.getUserBeenToReviews(userId: widget.userId);
    if (raw.isEmpty) return const [];

    final bestByLocationId = <int, _ReviewRow>{};
    for (var i = 0; i < raw.length; i++) {
      final row = raw[i];
      final locationId = (row['location_id'] as num?)?.toInt();
      final rating = (row['rating'] as num?)?.toDouble();
      if (locationId == null || rating == null) continue;
      final candidate = _ReviewRow(
        locationId: locationId,
        rating: rating,
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        sourceIndex: i,
      );
      final existing = bestByLocationId[locationId];
      if (existing == null) {
        bestByLocationId[locationId] = candidate;
        continue;
      }
      final ratingCmp = candidate.rating.compareTo(existing.rating);
      if (ratingCmp > 0) {
        bestByLocationId[locationId] = candidate;
        continue;
      }
      if (ratingCmp < 0) continue;
      final candidateTs = candidate.createdAt?.millisecondsSinceEpoch ?? 0;
      final existingTs = existing.createdAt?.millisecondsSinceEpoch ?? 0;
      if (candidateTs >= existingTs) {
        bestByLocationId[locationId] = candidate;
      }
    }
    if (bestByLocationId.isEmpty) return const [];

    final parsed = bestByLocationId.values.toList(growable: false);
    parsed.sort((a, b) {
      final ratingCmp = b.rating.compareTo(a.rating);
      if (ratingCmp != 0) return ratingCmp;
      final aTs = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTs = b.createdAt?.millisecondsSinceEpoch ?? 0;
      final createdCmp = bTs.compareTo(aTs);
      if (createdCmp != 0) return createdCmp;
      return a.sourceIndex.compareTo(b.sourceIndex);
    });

    final top = parsed.take(widget.maxPlaces).toList(growable: false);
    final locationIds = top.map((r) => r.locationId).toList(growable: false);

    final locations = await service.locations.getLocationsByIds(locationIds);
    if (locations.isEmpty) return const [];

    final byId = <int, LocationModel>{
      for (final loc in locations) loc.locationId: loc,
    };

    final out = <_RankedPlace>[];
    for (var i = 0; i < top.length; i++) {
      final review = top[i];
      final loc = byId[review.locationId];
      if (loc == null) continue;
      out.add(
        _RankedPlace(
          rank: i + 1,
          location: loc,
          userRating: review.rating,
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_RankedPlace>>(
      future: _future,
      builder: (context, snap) {
        final places = snap.data ?? const <_RankedPlace>[];
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 18);
        }
        if (places.isEmpty) return const SizedBox.shrink();

        final total = places.length.clamp(0, widget.maxPlaces);
        final visible = widget.allowExpand
            ? _visibleCount.clamp(0, total)
            : widget.collapsedPlacesCount.clamp(0, total);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(
            decoration: BoxDecoration(
              color: PinitColors.creamSunk,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: PinitColors.creamDeep,
                width: 1.5,
              ),
              boxShadow: PinitColors.subtleShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Been To Ranking',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: PinitColors.aubergineSoft,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      if (widget.showGateKeepToggle)
                        _GateKeepToggle(
                          value: _gateKeep,
                          disabled: _isUpdatingGateKeep,
                          onChanged: _setGateKeep,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final place in places.take(visible)) ...[
                    _RankedPlaceTile(
                      place: place,
                      onTap: () => _openPlace(place.location),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.allowExpand &&
                      total > widget.collapsedPlacesCount)
                    _ShareMoreButton(
                      label: visible < total ? 'See more' : 'Show less',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (visible < total) {
                            _visibleCount += widget.collapsedPlacesCount;
                          } else {
                            _visibleCount = widget.collapsedPlacesCount;
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openPlace(LocationModel location) {
    unawaited(
      RouteOpenGuard.run<void>(
        'expanded-location:${location.locationId}',
        () => showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel:
              MaterialLocalizations.of(context).modalBarrierDismissLabel,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (ctx, anim, _) => ExpandedLocationCard(
            location: location,
            onClose: () => Navigator.of(ctx).pop(),
          ),
          transitionBuilder: (ctx, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      ),
    );
  }
}

class _ReviewRow {
  const _ReviewRow({
    required this.locationId,
    required this.rating,
    required this.createdAt,
    required this.sourceIndex,
  });

  final int locationId;
  final double rating;
  final DateTime? createdAt;
  final int sourceIndex;
}

class _RankedPlace {
  const _RankedPlace({
    required this.rank,
    required this.location,
    required this.userRating,
  });

  final int rank;
  final LocationModel location;
  final double userRating;
}

@immutable
class BeenToRankedPlaceSeed {
  const BeenToRankedPlaceSeed({
    required this.rank,
    required this.location,
    required this.userRating,
  });

  final int rank;
  final LocationModel location;
  final double userRating;
}

class _GateKeepToggle extends StatelessWidget {
  final bool value;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  const _GateKeepToggle({
    required this.value,
    required this.disabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = value ? PinitColors.aubergine : PinitColors.cream;
    final fg = value ? PinitColors.cream : PinitColors.aubergine;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: disabled ? null : () => onChanged(!value),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  PinitColors.aubergine.withValues(alpha: value ? 0.0 : 0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 16,
                color: fg,
              ),
              const SizedBox(width: 6),
              Text(
                'Gate Keep',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  letterSpacing: 0.2,
                ),
              ),
              if (disabled) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      fg.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareMoreButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ShareMoreButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: PinitColors.aubergine,
          side: const BorderSide(color: PinitColors.aubergine, width: 1.6),
          backgroundColor: PinitColors.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: PinitColors.aubergine,
          ),
        ),
      ),
    );
  }
}

class _RankedPlaceTile extends StatelessWidget {
  final _RankedPlace place;
  final VoidCallback onTap;

  const _RankedPlaceTile({
    required this.place,
    required this.onTap,
  });

  static const _radius = 14.0;

  @override
  Widget build(BuildContext context) {
    final highlight = _highlightFor(place.rank);
    final borderColor = highlight?.border ?? PinitColors.aubergine;
    final bgColor = highlight?.background ?? PinitColors.cream;
    final badgeColor = highlight?.badge;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          height: 62,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1041133D),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              _RankBadge(rank: place.rank, highlight: badgeColor),
              const SizedBox(width: 8),
              _PlaceThumb(location: place.location),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  place.location.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.aubergine,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _RatingPill(
                rating: place.userRating,
                highlight: badgeColor,
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  _RankHighlight? _highlightFor(int rank) {
    switch (rank) {
      case 1:
        return const _RankHighlight(
          border: Color(0xFFD4AF37),
          background: Color(0x14D4AF37),
          badge: Color(0xFFD4AF37),
        );
      case 2:
        return const _RankHighlight(
          border: Color(0xFFC0C0C0),
          background: Color(0x14C0C0C0),
          badge: Color(0xFFC0C0C0),
        );
      case 3:
        return const _RankHighlight(
          border: Color(0xFFCD7F32),
          background: Color(0x14CD7F32),
          badge: Color(0xFFCD7F32),
        );
      default:
        return null;
    }
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final Color? highlight;

  const _RankBadge({
    required this.rank,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ?? PinitColors.aubergine;
    final bg = highlight != null
        ? color.withValues(alpha: 0.14)
        : PinitColors.creamDeep;
    final border = highlight != null
        ? color.withValues(alpha: 0.65)
        : PinitColors.aubergine.withValues(alpha: 0.2);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Text(
        '$rank',
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _RankHighlight {
  const _RankHighlight({
    required this.border,
    required this.background,
    required this.badge,
  });

  final Color border;
  final Color background;
  final Color badge;
}

class _PlaceThumb extends StatelessWidget {
  final LocationModel location;
  const _PlaceThumb({required this.location});

  @override
  Widget build(BuildContext context) {
    final url = location.imageUrl;
    final emoji = location.emoji;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 42,
        height: 42,
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: PinitColors.creamDeep,
                ),
                errorWidget: (_, __, ___) => _thumbFallback(emoji),
              )
            : _thumbFallback(emoji),
      ),
    );
  }

  Widget _thumbFallback(String? emoji) {
    return Container(
      color: PinitColors.creamDeep,
      alignment: Alignment.center,
      child: Text(
        (emoji != null && emoji.isNotEmpty) ? emoji : '📍',
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;
  final Color? highlight;

  const _RatingPill({
    required this.rating,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ?? PinitColors.aubergine;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: PinitColors.aubergine,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
