import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/referral_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ReferralPromptService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = ReferralPromptService();
  });

  test('does not show until a prompt is pending for the user', () async {
    expect(await service.shouldShowForUser('user-1'), isFalse);

    await service.markPendingForUser('user-1');

    expect(await service.shouldShowForUser('user-1'), isTrue);
    expect(await service.shouldShowForUser('user-2'), isFalse);
  });

  test('markHandledForUser clears the pending prompt', () async {
    await service.markPendingForUser('user-1');
    await service.markHandledForUser('user-1');

    expect(await service.shouldShowForUser('user-1'), isFalse);
  });
}
