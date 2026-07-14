import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/location_processing_trigger.dart';

void main() {
  final now = DateTime.utc(2026, 7, 14, 12);

  test('incomplete never-queued row requests processing', () {
    final row = _completeRow()..['generated_summary'] = ' ';

    expect(
      LocationProcessingSnapshot.fromRow(row).shouldProcess(now),
      isTrue,
    );
  });

  test('fresh tracker blocks missing fields', () {
    final row = _completeRow()
      ..['generated_summary'] = null
      ..['location_processing_queued_at'] =
          now.subtract(const Duration(days: 1)).toIso8601String();

    expect(
      LocationProcessingSnapshot.fromRow(row).shouldProcess(now),
      isFalse,
    );
  });

  test('complete row with empty tracker does not request processing', () {
    expect(
      LocationProcessingSnapshot.fromRow(_completeRow()).shouldProcess(now),
      isFalse,
    );
  });

  test('thirty-day-old tracker requests refresh for complete row', () {
    final row = _completeRow()
      ..['location_processing_queued_at'] =
          now.subtract(const Duration(days: 30)).toIso8601String();

    expect(
      LocationProcessingSnapshot.fromRow(row).shouldProcess(now),
      isTrue,
    );
  });

  test('tracker newer than thirty days blocks refresh', () {
    final row = _completeRow()
      ..['location_processing_queued_at'] =
          now.subtract(const Duration(days: 29, hours: 23)).toIso8601String();

    expect(
      LocationProcessingSnapshot.fromRow(row).shouldProcess(now),
      isFalse,
    );
  });

  test('legacy JSON-string reviews count as present', () {
    final row = _completeRow()..['reviews'] = '[{"rating":5}]';

    expect(LocationProcessingSnapshot.fromRow(row).hasMajorGaps, isFalse);
  });

  test('each major missing field makes a never-queued row eligible', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (row) => row['generated_summary'] = null,
      (row) => row['emoji'] = '',
      (row) {
        row['image_stored'] = false;
        row['image_unavailable'] = false;
      },
      (row) => row['cuisine_primary'] = null,
      (row) => row['dietary_requirement_vector'] = <int>[],
      (row) => row['vibe_vector'] = <int>[],
      (row) => row['updated_vibe'] = false,
      (row) => row['google_place_id'] = ' ',
      (row) => row['google_maps_uri'] = null,
      (row) => row['reviews'] = <dynamic>[],
    ];

    for (final mutate in mutations) {
      final row = _completeRow();
      mutate(row);
      expect(
        LocationProcessingSnapshot.fromRow(row).hasMajorGaps,
        isTrue,
      );
      expect(
        LocationProcessingSnapshot.fromRow(row).shouldProcess(now),
        isTrue,
      );
    }
  });

  test('eligible snapshot sends one canonical request', () async {
    final requests = <({int locationId, String? googlePlaceId})>[];
    final trigger = LocationProcessingTrigger(
      loadRow: (_) async => _completeRow()..['emoji'] = null,
      requestProcessing: ({required locationId, googlePlaceId}) async {
        requests.add((
          locationId: locationId,
          googlePlaceId: googlePlaceId,
        ));
      },
      now: () => now,
    );

    expect(await trigger.onExpanded(42), isTrue);
    expect(
      requests,
      [(locationId: 42, googlePlaceId: 'place-42')],
    );
  });

  test('fresh cooldown performs no API request', () async {
    var requested = false;
    final trigger = LocationProcessingTrigger(
      loadRow: (_) async => _completeRow()
        ..['emoji'] = null
        ..['location_processing_queued_at'] = now.toIso8601String(),
      requestProcessing: ({required locationId, googlePlaceId}) async {
        requested = true;
      },
      now: () => now,
    );

    expect(await trigger.onExpanded(42), isFalse);
    expect(requested, isFalse);
  });

  test('invalid or missing location performs no API request', () async {
    var loads = 0;
    var requests = 0;
    final trigger = LocationProcessingTrigger(
      loadRow: (_) async {
        loads += 1;
        return null;
      },
      requestProcessing: ({required locationId, googlePlaceId}) async {
        requests += 1;
      },
      now: () => now,
    );

    expect(await trigger.onExpanded(0), isFalse);
    expect(await trigger.onExpanded(42), isFalse);
    expect(loads, 1);
    expect(requests, 0);
  });
}

Map<String, dynamic> _completeRow() => <String, dynamic>{
      'location_id': 42,
      'google_place_id': 'place-42',
      'location_processing_queued_at': null,
      'generated_summary': 'A concise story.',
      'emoji': '🍜',
      'image_stored': true,
      'image_unavailable': false,
      'cuisine_primary': 'Japanese',
      'dietary_requirement_vector': <int>[0, 1],
      'vibe_vector': <int>[1, 0],
      'updated_vibe': true,
      'google_maps_uri': 'https://maps.google.com/?cid=42',
      'reviews': <Map<String, dynamic>>[
        <String, dynamic>{'rating': 5},
      ],
    };
