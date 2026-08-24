import 'package:flutter_test/flutter_test.dart';
import 'package:login/supabase/auth_signout_reason.dart';

void main() {
  test('exposes a stable reason for every sign-out path', () {
    expect(AuthSignOutReason.values.map((r) => r.name).toSet(), <String>{
      'userInitiated',
      'startupSessionInvalid',
      'authEventSessionInvalid',
      'authStreamFatalError',
      'passwordRecoveryCompleted',
      'accountDeleted',
    });
  });

  test('reason wire names are snake_case and unique', () {
    final wireNames = AuthSignOutReason.values.map((r) => r.wireName).toList();
    expect(wireNames.toSet().length, wireNames.length);
    for (final name in wireNames) {
      expect(name, matches(RegExp(r'^[a-z0-9_]+$')));
    }
  });
}
