import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/onboarding_resume_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('consume resumes once for a previous session, then never again',
      () async {
    SharedPreferences.setMockInitialValues({'onboarding_in_progress_u1': true});
    final service = OnboardingResumeService();

    expect(await service.consume('u1'), isTrue);
    expect(await service.consume('u1'), isFalse);
  });

  test('flags are per user', () async {
    SharedPreferences.setMockInitialValues({'onboarding_in_progress_u1': true});
    expect(await OnboardingResumeService().consume('u2'), isFalse);
  });

  test('never resumes the onboarding that started in this session', () async {
    final service = OnboardingResumeService();
    await service.markInProgress('u1');

    expect(await service.consume('u1'), isFalse);

    // Completing onboarding clears the flag and the session marker.
    await service.clear('u1');
    expect(await service.consume('u1'), isFalse);
  });
}
