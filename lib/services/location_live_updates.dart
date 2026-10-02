import 'dart:async';

import 'package:login/models/locations.dart';
import 'package:login/services/location_processing_trigger.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How long after `location_processing_queued_at` a place with gaps still
/// counts as being filled in. Covers Pub/Sub delivery, worker cold start and
/// the slower AI stages; after this the card stops saying it is working.
const Duration locationEnrichmentWindow = Duration(minutes: 3);

typedef LocationRowWatch = void Function() Function(
  int locationId,
  void Function() onChange,
);

typedef LocationRowReader = Future<Map<String, dynamic>?> Function(
  int locationId,
);

/// Watches one `locations` row while its card is open, so details written by
/// the processing worker (Pub/Sub or in-process, one row write per stage)
/// show up without reopening the card.
///
/// Change events are only a signal: each burst triggers one re-read of the
/// row, which avoids Realtime payload limits on large rows (reviews, menu).
class LocationLiveUpdates {
  LocationLiveUpdates({
    required this.locationId,
    required this.onRow,
    LocationRowWatch? watch,
    LocationRowReader? readRow,
    this.debounce = const Duration(milliseconds: 600),
  })  : _watch = watch ?? _watchWithRealtime,
        _readRow = readRow ?? _readCanonicalRow;

  final int locationId;
  final void Function(Map<String, dynamic> row) onRow;
  final Duration debounce;
  final LocationRowWatch _watch;
  final LocationRowReader _readRow;

  void Function()? _unwatch;
  Timer? _debounceTimer;
  bool _disposed = false;

  void start() {
    if (_disposed || _unwatch != null || locationId <= 0) return;
    _unwatch = _watch(locationId, _onChange);
  }

  /// Re-reads the row now (e.g. once processing has been requested, in case
  /// a stage finished before the subscription was live).
  Future<void> refresh() => _reload();

  void _onChange() {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, _reload);
  }

  Future<void> _reload() async {
    if (_disposed) return;
    try {
      final row = await _readRow(locationId);
      if (row != null && !_disposed) onRow(row);
    } catch (_) {
      // A missed refresh is harmless; the next change or open re-reads.
    }
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _unwatch?.call();
    _unwatch = null;
  }

  static void Function() _watchWithRealtime(
    int locationId,
    void Function() onChange,
  ) {
    final client = SupabaseClientManager().client;
    final channel = client
        .channel('location_live:$locationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'location_id',
            value: locationId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
    return () => client.removeChannel(channel);
  }

  static Future<Map<String, dynamic>?> _readCanonicalRow(int locationId) {
    return SupabaseClientManager()
        .client
        .from('locations')
        .select()
        .eq('location_id', locationId)
        .maybeSingle();
  }
}

/// True while the worker is plausibly still filling this row in: it was
/// queued recently and still has gaps the worker fills.
bool isLocationBeingEnriched(Map<String, dynamic> row, DateTime now) {
  if (!LocationProcessingSnapshot.fromRow(row).hasMajorGaps) return false;
  final queuedAt = DateTime.tryParse(
    row['location_processing_queued_at']?.toString() ?? '',
  )?.toUtc();
  if (queuedAt == null) return false;
  return now.toUtc().difference(queuedAt) < locationEnrichmentWindow;
}

extension LocationStoredDetails on LocationModel {
  /// This location with the database-backed fields of [fresh] applied.
  /// App-side context (match score, saved state, friend saves, distance,
  /// search metadata) is kept, and null fresh values never erase data.
  LocationModel withStoredDetails(LocationModel fresh) {
    return copyWith(
      name: fresh.name,
      vicinity: fresh.vicinity,
      rating: fresh.rating,
      userRatingsTotal: fresh.userRatingsTotal,
      priceLevel: fresh.priceLevel,
      googlePlaceId: fresh.googlePlaceId,
      businessStatus: fresh.businessStatus,
      editorialSummary: fresh.editorialSummary,
      website: fresh.website,
      internationalPhoneNumber: fresh.internationalPhoneNumber,
      types: fresh.types,
      openingHoursText: fresh.openingHoursText,
      openingHoursPeriods: fresh.openingHoursPeriods,
      openNow: fresh.openNow,
      cuisinePrimary: fresh.cuisinePrimary,
      cuisineKey: fresh.cuisineKey,
      emoji: fresh.emoji,
      imageStored: fresh.imageStored,
      imageUnavailable: fresh.imageUnavailable,
      extraPhotosStored: fresh.extraPhotosStored,
      googleMapsUri: fresh.googleMapsUri,
      photos: fresh.photos,
      reviews: fresh.reviews,
      reviewSummary: fresh.reviewSummary,
      goodForChildren: fresh.goodForChildren,
      goodForGroups: fresh.goodForGroups,
      goodForWatchingSports: fresh.goodForWatchingSports,
      liveMusic: fresh.liveMusic,
      outdoorSeating: fresh.outdoorSeating,
      servesBeer: fresh.servesBeer,
      servesBreakfast: fresh.servesBreakfast,
      servesBrunch: fresh.servesBrunch,
      servesCocktails: fresh.servesCocktails,
      servesCoffee: fresh.servesCoffee,
      servesDessert: fresh.servesDessert,
      servesDinner: fresh.servesDinner,
      servesLunch: fresh.servesLunch,
      servesVegetarianFood: fresh.servesVegetarianFood,
      servesWine: fresh.servesWine,
      menu: fresh.menu,
      generatedSummary: fresh.generatedSummary,
      recommendedDishes: fresh.recommendedDishes,
      menuAnalysisConfidence: fresh.menuAnalysisConfidence,
      vibeVector: fresh.vibeVector,
      vibe: fresh.vibe,
      updatedVibe: fresh.updatedVibe,
      dietaryRequirementVector: fresh.dietaryRequirementVector,
      cuisineScoresJson: fresh.cuisineScoresJson,
    );
  }
}
