import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/referral_code_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReferralCodePromptService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('shows only after pending and before completion for current user',
        () async {
      final service = ReferralCodePromptService(currentUserId: () => 'user-1');

      expect(await service.shouldShowNow(), isFalse);

      await service.markPending();
      expect(await service.shouldShowNow(), isTrue);

      await service.markCompleted();
      expect(await service.shouldShowNow(), isFalse);
    });

    test('scopes prompt state per user', () async {
      var userId = 'user-1';
      final service = ReferralCodePromptService(currentUserId: () => userId);

      await service.markPending();
      expect(await service.shouldShowNow(), isTrue);

      userId = 'user-2';
      expect(await service.shouldShowNow(), isFalse);
    });
  });
}
