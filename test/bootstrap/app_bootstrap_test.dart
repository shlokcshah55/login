import 'package:flutter_test/flutter_test.dart';
import 'package:login/bootstrap/app_dependencies.dart';

void main() {
  test('deferred initializer runs once', () async {
    var calls = 0;
    final initializer = DeferredAppInitializer(
      initialize: () async {
        calls += 1;
      },
    );

    await Future.wait(<Future<void>>[
      initializer.start(),
      initializer.start(),
    ]);

    expect(calls, 1);
  });

  test('deferred initializer exposes the same failure to all callers',
      () async {
    var calls = 0;
    final initializer = DeferredAppInitializer(
      initialize: () async {
        calls += 1;
        throw StateError('failed');
      },
    );

    final first = initializer.start();
    final second = initializer.start();

    await expectLater(first, throwsStateError);
    await expectLater(second, throwsStateError);
    expect(calls, 1);
  });
}
