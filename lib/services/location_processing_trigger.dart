import 'dart:convert';

import 'package:login/services/recommendations_api.dart';
import 'package:login/supabase/supabase_client.dart';

const locationProcessingCooldown = Duration(days: 30);

const _processingSnapshotColumns = <String>[
  'location_id',
  'google_place_id',
  'location_processing_queued_at',
  'generated_summary',
  'emoji',
  'image_stored',
  'image_unavailable',
  'cuisine_primary',
  'dietary_requirement_vector',
  'vibe_vector',
  'updated_vibe',
  'google_maps_uri',
  'reviews',
];

bool _present(Object? value) => value?.toString().trim().isNotEmpty == true;

bool _hasItems(Object? value) {
  if (value is Iterable) return value.isNotEmpty;
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Iterable && decoded.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
  return false;
}

class LocationProcessingSnapshot {
  const LocationProcessingSnapshot({
    required this.locationId,
    required this.googlePlaceId,
    required this.queuedAt,
    required this.hasMajorGaps,
  });

  final int locationId;
  final String? googlePlaceId;
  final DateTime? queuedAt;
  final bool hasMajorGaps;

  factory LocationProcessingSnapshot.fromRow(Map<String, dynamic> row) {
    final queuedAt = DateTime.tryParse(
      row['location_processing_queued_at']?.toString() ?? '',
    )?.toUtc();
    final photoTerminal =
        row['image_stored'] == true || row['image_unavailable'] == true;
    final hasMajorGaps = !_present(row['generated_summary']) ||
        !_present(row['emoji']) ||
        !photoTerminal ||
        !_present(row['cuisine_primary']) ||
        !_hasItems(row['dietary_requirement_vector']) ||
        !_hasItems(row['vibe_vector']) ||
        row['updated_vibe'] != true ||
        !_present(row['google_place_id']) ||
        !_present(row['google_maps_uri']) ||
        !_hasItems(row['reviews']);

    return LocationProcessingSnapshot(
      locationId: (row['location_id'] as num).toInt(),
      googlePlaceId: row['google_place_id']?.toString().trim(),
      queuedAt: queuedAt,
      hasMajorGaps: hasMajorGaps,
    );
  }

  bool shouldProcess(DateTime now) {
    final lastQueued = queuedAt;
    if (lastQueued == null) return hasMajorGaps;
    return !now.toUtc().isBefore(lastQueued.add(locationProcessingCooldown));
  }
}

typedef LocationProcessingRowLoader = Future<Map<String, dynamic>?> Function(
  int locationId,
);

typedef LocationProcessingRequester = Future<void> Function({
  required int locationId,
  String? googlePlaceId,
});

class LocationProcessingTrigger {
  LocationProcessingTrigger({
    LocationProcessingRowLoader? loadRow,
    LocationProcessingRequester? requestProcessing,
    DateTime Function()? now,
  })  : _loadRow = loadRow ?? _loadCanonicalRow,
        _requestProcessing = requestProcessing ?? _requestCanonicalProcessing,
        _now = now ?? DateTime.now;

  final LocationProcessingRowLoader _loadRow;
  final LocationProcessingRequester _requestProcessing;
  final DateTime Function() _now;

  Future<bool> onExpanded(int locationId) async {
    if (locationId <= 0) return false;

    final row = await _loadRow(locationId);
    if (row == null) return false;

    final snapshot = LocationProcessingSnapshot.fromRow(row);
    if (!snapshot.shouldProcess(_now())) return false;

    await _requestProcessing(
      locationId: snapshot.locationId,
      googlePlaceId: snapshot.googlePlaceId,
    );
    return true;
  }

  static Future<Map<String, dynamic>?> _loadCanonicalRow(
    int locationId,
  ) async {
    return SupabaseClientManager()
        .client
        .from('locations')
        .select(_processingSnapshotColumns.join(','))
        .eq('location_id', locationId)
        .maybeSingle();
  }

  static Future<void> _requestCanonicalProcessing({
    required int locationId,
    String? googlePlaceId,
  }) {
    return RecommendationsApi().processLocation(
      locationId: locationId,
      googlePlaceId: googlePlaceId,
      source: 'expanded-card-open',
    );
  }
}
