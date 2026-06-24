import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/push_notification_service.dart';

void main() {
  test('bubble message title highlights @ mentions', () {
    expect(
      buildBubbleMessageNotificationTitle(
        bubbleName: 'Weekend Plans',
        senderName: 'Alex',
        messageContent: 'Meet @Sam at 8?',
      ),
      'New mention from Alex in Weekend Plans',
    );
  });

  test('bubble message title keeps default copy without @ mentions', () {
    expect(
      buildBubbleMessageNotificationTitle(
        bubbleName: 'Weekend Plans',
        senderName: 'Alex',
        messageContent: 'Meet Sam at 8?',
      ),
      'New message in Weekend Plans',
    );
  });
}
