import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/proximity/proximity_geofence_bridge.dart';
import 'package:login/services/proximity/proximity_regions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/geofence');
  late MethodChannelGeofenceBridge bridge;
  late List<MethodCall> calls;
  late Object? Function(MethodCall) respond;

  setUp(() {
    calls = [];
    respond = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return respond(call);
    });
    bridge = MethodChannelGeofenceBridge.forTesting(channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> fromNative(String method, Object? args) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
  }

  test('parses every authorization status', () {
    expect(LocationAuthStatus.parse('always'), LocationAuthStatus.always);
    expect(LocationAuthStatus.parse('whenInUse'), LocationAuthStatus.whenInUse);
    expect(LocationAuthStatus.parse('denied'), LocationAuthStatus.denied);
    expect(
      LocationAuthStatus.parse('notDetermined'),
      LocationAuthStatus.notDetermined,
    );
    expect(
        LocationAuthStatus.parse('restricted'), LocationAuthStatus.restricted);
    expect(LocationAuthStatus.parse(null), LocationAuthStatus.unsupported);
    expect(LocationAuthStatus.whenInUse.canStillUpgrade, isTrue);
    expect(LocationAuthStatus.denied.canStillUpgrade, isFalse);
  });

  test('authorizationStatus reads the native string', () async {
    respond = (_) => 'whenInUse';
    expect(await bridge.authorizationStatus(), LocationAuthStatus.whenInUse);
  });

  test('registerRegions sends plain maps', () async {
    await bridge.registerRegions(const [
      GeofenceRegion(
        id: '7',
        latitude: 51.5,
        longitude: -0.1,
        radiusMeters: 400,
      ),
    ]);

    expect(calls.single.method, 'registerRegions');
    final regions = (calls.single.arguments as Map)['regions'] as List;
    expect(regions.single, {
      'id': '7',
      'latitude': 51.5,
      'longitude': -0.1,
      'radius': 400.0,
    });
  });

  test('postNotification reports whether native posted it', () async {
    respond = (_) => true;
    expect(
      await bridge.postNotification(
        id: 'p1',
        title: 't',
        body: 'b',
        payload: const {'deepLink': 'pinit://location/1'},
      ),
      isTrue,
    );
    expect(
        calls.single.arguments['payload'], {'deepLink': 'pinit://location/1'});

    respond = (_) => false;
    expect(
      await bridge
          .postNotification(id: 'p1', title: 't', body: 'b', payload: const {}),
      isFalse,
    );
  });

  test('a native failure degrades to a quiet default', () async {
    respond = (_) => throw PlatformException(code: 'X');
    expect(
      await bridge
          .postNotification(id: 'p1', title: 't', body: 'b', payload: const {}),
      isFalse,
    );
    expect(await bridge.authorizationStatus(), LocationAuthStatus.unsupported);
  });

  test('native events become typed Dart events', () async {
    final events = <GeofenceEvent>[];
    final sub = bridge.events.listen(events.add);

    await fromNative('onGeofenceEvent', {
      'event': 'enter',
      'identifier': '42',
      'latitude': 51.5,
      'longitude': -0.1,
    });
    await fromNative('onGeofenceEvent', {'event': 'enter', 'identifier': '43'});
    await fromNative('onSignificantLocationChange', {
      'latitude': 1.0,
      'longitude': 2.0,
    });
    await fromNative('onAuthorizationChanged', {'status': 'always'});
    await fromNative('onNotificationTap', {
      'payload': {'deepLink': 'pinit://location/42'},
    });
    // Ignored: wrong event, unparsable id, missing coordinates.
    await fromNative('onGeofenceEvent', {'event': 'exit', 'identifier': '42'});
    await fromNative('onGeofenceEvent', {'event': 'enter', 'identifier': 'x'});
    await fromNative('onSignificantLocationChange', {'latitude': 1.0});
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(events, hasLength(5));
    final entered = events[0] as GeofenceEntered;
    expect(entered.locationId, 42);
    expect(entered.position!.latitude, 51.5);
    expect((events[1] as GeofenceEntered).position, isNull);
    expect((events[2] as SignificantLocationChange).position.longitude, 2.0);
    expect(
        (events[3] as AuthorizationChanged).status, LocationAuthStatus.always);
    expect(
      (events[4] as NotificationTapped).payload['deepLink'],
      'pinit://location/42',
    );
  });

  test('is a quiet no-op when unsupported', () async {
    final unsupported = MethodChannelGeofenceBridge();
    expect(unsupported.isSupported, isFalse);
    expect(await unsupported.authorizationStatus(),
        LocationAuthStatus.unsupported);
    await unsupported.registerRegions(const []);
    expect(
      await unsupported
          .postNotification(id: 'a', title: 'b', body: 'c', payload: const {}),
      isFalse,
    );
    expect(calls, isEmpty);
  });
}
