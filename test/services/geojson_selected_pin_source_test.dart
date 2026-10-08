import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/geojson_map_layer_service.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:mocktail/mocktail.dart';

class _MockMapboxMap extends Mock implements mapbox.MapboxMap {}

class _MockStyle extends Mock implements mapbox.StyleManager {}

class _FakeMbxImage extends Fake implements mapbox.MbxImage {}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakeMbxImage());
  });

  late _MockMapboxMap map;
  late _MockStyle style;
  late GeoJsonMapLayerService service;

  const config = GeoJsonLayerConfig();
  final selectedSourceId = '${config.sourceId}-selected';

  LocationModel place(int id) => LocationModel(
        locationId: id,
        name: 'Place $id',
        createdAt: DateTime(2026, 1, 1),
        lat: 51.5 + id / 1000,
        lng: -0.1,
      );

  setUp(() {
    map = _MockMapboxMap();
    style = _MockStyle();
    when(() => map.style).thenReturn(style);
    when(() => style.addStyleSource(any(), any())).thenAnswer((_) async {});
    when(() => style.addStyleLayer(any(), any())).thenAnswer((_) async {});
    when(() => style.addStyleImage(
        any(), any(), any(), any(), any(), any(), any())).thenAnswer((_) async {});
    when(() => style.setStyleLayerProperty(any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => style.setStyleSourceProperty(any(), any(), any()))
        .thenAnswer((_) async {});
    service = GeoJsonMapLayerService(mapboxMap: map, config: config);
  });

  /// Marker icons render with Google Fonts, which can't load in tests; those
  /// load failures are dropped so they don't fail unrelated assertions.
  Future<void> run(WidgetTester tester, Future<void> Function() body) async {
    await tester.runAsync(() {
      final done = Completer<void>();
      runZonedGuarded(() async {
        await body();
        done.complete();
      }, (error, stack) {
        if (error.toString().contains('font')) return;
        if (!done.isCompleted) done.completeError(error, stack);
      });
      return done.future;
    });
  }

  List<int> selectedSourceIds() {
    final writes = verify(() => style.setStyleSourceProperty(
            selectedSourceId, 'data', captureAny()))
        .captured;
    final last = jsonDecode(writes.last as String) as Map<String, dynamic>;
    return [
      for (final f in last['features'] as List)
        (f as Map<String, dynamic>)['properties']['locationId'] as int,
    ];
  }

  testWidgets('selected pin is drawn from its own unclustered source',
      (tester) async {
    await run(tester, service.initialize);

    final sources = verify(() => style.addStyleSource(captureAny(), captureAny()))
        .captured;
    final selectedIndex = sources.indexOf(selectedSourceId);
    expect(selectedIndex, isNonNegative);
    final selectedSource =
        jsonDecode(sources[selectedIndex + 1] as String) as Map<String, dynamic>;
    expect(selectedSource['cluster'], isNot(true));

    final layers = verify(() => style.addStyleLayer(captureAny(), any()))
        .captured
        .map((json) => jsonDecode(json as String) as Map<String, dynamic>);
    final selectedLayer =
        layers.firstWhere((l) => l['id'] == 'pinit-selected-pin');
    expect(selectedLayer['source'], selectedSourceId);
  });

  testWidgets('selecting a place writes only that place to the selected source',
      (tester) async {
    await run(tester, () async {
      await service.initialize();
      await service.updateLocations([place(1), place(2), place(3)]);
      service.setSelectedLocation('2');
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    expect(selectedSourceIds(), [2]);

    await run(tester, () async {
      service.setSelectedLocation(null);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(selectedSourceIds(), isEmpty);
  });
}
