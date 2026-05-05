import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:login/utils/route_open_guard.dart';

void main() {
  group('RouteOpenGuard', () {
    test('runs only once per key until completion', () async {
      final completer = Completer<int?>();
      var calls = 0;

      final first = RouteOpenGuard.run<int>('k', () {
        calls += 1;
        return completer.future;
      });

      final second = RouteOpenGuard.run<int>('k', () async {
        calls += 1;
        return 2;
      });

      expect(calls, 1);
      expect(await second, isNull);

      completer.complete(1);
      expect(await first, 1);

      final third = RouteOpenGuard.run<int>('k', () async {
        calls += 1;
        return 3;
      });

      expect(await third, 3);
      expect(calls, 2);
    });

    test('clears key if action throws synchronously', () async {
      final failing = RouteOpenGuard.run<void>('k2', () {
        throw Exception('boom');
      });

      await expectLater(failing, throwsException);

      final after = RouteOpenGuard.run<String>('k2', () async => 'ok');
      expect(await after, 'ok');
    });
  });
}
