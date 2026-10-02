import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/location_live_updates.dart';

Map<String, dynamic> _gappyRow({String? queuedAt}) => {
      'location_id': 7,
      'google_place_id': 'gp-7',
      'location_processing_queued_at': queuedAt,
    };

void main() {
  group('LocationLiveUpdates', () {
    late void Function() fire;
    late int unwatched;
    late int reads;
    late List<Map<String, dynamic>> delivered;

    LocationLiveUpdates build() {
      unwatched = 0;
      reads = 0;
      delivered = [];
      return LocationLiveUpdates(
        locationId: 7,
        onRow: delivered.add,
        debounce: const Duration(milliseconds: 20),
        watch: (id, onChange) {
          expect(id, 7);
          fire = onChange;
          return () => unwatched++;
        },
        readRow: (id) async {
          reads++;
          return {'location_id': id, 'read': reads};
        },
      );
    }

    test('a burst of row writes causes one re-read', () async {
      final live = build()..start();
      fire();
      fire();
      fire();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(reads, 1);
      expect(delivered.single['read'], 1);
      live.dispose();
    });

    test('refresh reads immediately', () async {
      final live = build()..start();
      await live.refresh();
      expect(delivered, hasLength(1));
      live.dispose();
    });

    test('dispose unsubscribes and drops pending reads', () async {
      final live = build()..start();
      fire();
      live.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(unwatched, 1);
      expect(reads, 0);
      expect(delivered, isEmpty);
    });
  });

  group('isLocationBeingEnriched', () {
    final now = DateTime.utc(2026, 10, 2, 12);

    test('recently queued with gaps is in progress', () {
      final queued = now.subtract(const Duration(seconds: 30)).toIso8601String();
      expect(isLocationBeingEnriched(_gappyRow(queuedAt: queued), now), isTrue);
    });

    test('stops after the window or when never queued', () {
      final old = now.subtract(locationEnrichmentWindow).toIso8601String();
      expect(isLocationBeingEnriched(_gappyRow(queuedAt: old), now), isFalse);
      expect(isLocationBeingEnriched(_gappyRow(), now), isFalse);
    });
  });

  group('withStoredDetails', () {
    test('fills details from the row and keeps app-side context', () {
      final opened = LocationModel(
        locationId: 7,
        name: 'Venue',
        createdAt: DateTime.utc(2025, 1, 1),
        matchScore: 0.8,
        website: 'https://old.example',
      );
      final fresh = LocationModel(
        locationId: 7,
        name: 'Venue',
        createdAt: DateTime.utc(2025, 1, 1),
        openingHoursText: const ['Mon: 9–5'],
        generatedSummary: 'Small natural wine bar.',
      );

      final merged = opened.withStoredDetails(fresh);
      expect(merged.openingHoursText, ['Mon: 9–5']);
      expect(merged.generatedSummary, 'Small natural wine bar.');
      expect(merged.matchScore, 0.8);
      expect(merged.website, 'https://old.example'); // null never erases
    });
  });
}
