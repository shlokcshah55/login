import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/fcm_service.dart';

void main() {
  test('shouldSyncFcmToken skips Apple sync until APNS token exists', () {
    expect(
      shouldSyncFcmToken(
        isApplePlatform: true,
        apnsToken: null,
        fcmToken: 'fcm-token',
      ),
      isFalse,
    );
  });

  test('shouldSyncFcmToken allows Apple sync when APNS and FCM tokens exist',
      () {
    expect(
      shouldSyncFcmToken(
        isApplePlatform: true,
        apnsToken: 'apns-token',
        fcmToken: 'fcm-token',
      ),
      isTrue,
    );
  });

  test('shouldSyncFcmToken skips sync when FCM token is empty', () {
    expect(
      shouldSyncFcmToken(
        isApplePlatform: false,
        apnsToken: null,
        fcmToken: '',
      ),
      isFalse,
    );
  });

  test('shouldClearFcmToken skips backend clear when token is unavailable', () {
    expect(shouldClearFcmToken(currentToken: null), isFalse);
    expect(shouldClearFcmToken(currentToken: ''), isFalse);
  });

  test('shouldClearFcmToken allows backend clear when token exists', () {
    expect(shouldClearFcmToken(currentToken: 'fcm-token'), isTrue);
  });
}
