import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/services/geojson_map_layer_service.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:mocktail/mocktail.dart';

class _MockMapboxMap extends Mock implements mapbox.MapboxMap {}

class _MockAnnotationManager extends Mock
    implements mapbox.AnnotationManager {}

class _MockPolylineManager extends Mock
    implements mapbox.PolylineAnnotationManager {}

/// Records every list applied, and lets a test hold an update open to
/// simulate a slow icon registration.
class _FakeLayerService extends Fake implements GeoJsonMapLayerService {
  final applied = <List<int>>[];
  Completer<void>? gate;
  int failuresRemaining = 0;
  bool _initialized = false;
  int resets = 0;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async => _initialized = true;

  @override
  Future<void> updateLocations(
    List<LocationModel> locations, {
    Set<int> beenToLocationIds = const <int>{},
  }) async {
    final pending = gate;
    if (pending != null) await pending.future;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('source missing');
    }
    applied.add(locations.map((l) => l.locationId).toList());
  }

  @override
  void resetForNewStyle() {
    resets++;
    _initialized = false;
  }

  @override
  void detach() => _initialized = false;

  @override
  Future<void> setDotsByDefault(bool value) async {}

  @override
  void markLocationAsRecentlySaved(int locationId) {}
}

void main() {
  late _FakeLayerService service;
  late MapStateProvider provider;
  late _MockMapboxMap map;

  setUp(() {
    service = _FakeLayerService();
    provider = MapStateProvider(
      layerServiceFactory: (map, {onLocationTapped, onClusterTapped}) =>
          service,
    );
    map = _MockMapboxMap();
    final annotations = _MockAnnotationManager();
    when(() => map.annotations).thenReturn(annotations);
    when(() => annotations.createPolylineAnnotationManager())
        .thenAnswer((_) async => _MockPolylineManager());
  });

  test('pins requested before the style loads are applied when it does',
      () async {
    provider.requestPins([_location(1), _location(2)]);
    await provider.setMapboxMap(map);
    await pumpEventQueue();
    expect(service.applied, isEmpty);

    provider.onStyleLoaded();
    await pumpEventQueue();

    expect(service.applied, [
      [1, 2]
    ]);
  });

  test('overlapping requests never interleave and the latest wins', () async {
    await provider.setMapboxMap(map);
    provider.onStyleLoaded();

    service.gate = Completer<void>();
    provider.requestPins([_location(1)]);
    await pumpEventQueue();

    // Both arrive while the first update is still in flight.
    provider.requestPins([_location(2)]);
    provider.requestPins([_location(3)]);
    service.gate!.complete();
    service.gate = null;
    await pumpEventQueue();

    expect(service.applied, [
      [1],
      [3],
    ]);
  });

  // testWidgets runs in fake time, so the retry backoff can be advanced.
  testWidgets('a failed sync retries on its own', (tester) async {
    await provider.setMapboxMap(map);
    provider.onStyleLoaded();
    service.failuresRemaining = 2;

    provider.requestPins([_location(7)]);
    await tester.pump();
    expect(service.applied, isEmpty);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.applied, [
      [7]
    ]);
  });

  test('a style reload rebuilds layers and re-applies the last pins',
      () async {
    await provider.setMapboxMap(map);
    provider.onStyleLoaded();
    provider.requestPins([_location(4), _location(5)]);
    await pumpEventQueue();

    provider.onStyleLoaded();
    await pumpEventQueue();

    expect(service.resets, 1);
    expect(service.applied, [
      [4, 5],
      [4, 5],
    ]);
  });

  test('a new map re-applies the last pins once its style loads', () async {
    await provider.setMapboxMap(map);
    provider.onStyleLoaded();
    provider.requestPins([_location(9)]);
    await pumpEventQueue();

    await provider.setMapboxMap(map);
    await pumpEventQueue();
    expect(service.applied, [
      [9]
    ]);

    provider.onStyleLoaded();
    await pumpEventQueue();
    expect(service.applied, [
      [9],
      [9],
    ]);
  });
}

LocationModel _location(int id) => LocationModel(
      locationId: id,
      name: 'Place $id',
      lat: 51.5,
      lng: -0.12 + id * 0.001,
      createdAt: DateTime(2026, 5, 1),
    );
