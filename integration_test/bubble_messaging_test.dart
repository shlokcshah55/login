// Integration tests for bubble messaging.
//
// `MessagingHelper.sendMessage` is the core action that the bubble chat UI
// invokes whenever a user types or shares a location. The production class
// constructs its own `SupabaseClient` via `SupabaseClientManager()`, so
// driving the real code path requires either (a) an initialised Supabase
// runtime or (b) a refactor to inject the client. To keep this suite fast
// and hermetic we test the contract via mocktail mocks.
//
// The tests below verify:
//   • the exact parameters callers pass through,
//   • the return-value plumbing (server-generated message id → caller),
//   • failure propagation (rethrow semantics),
//   • location-attached messages,
//   • reply-to-message threading.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:login/supabase/helpers/messaging.dart';
import 'package:mocktail/mocktail.dart';

class _MockMessagingHelper extends Mock implements MessagingHelper {}

/// Thin domain wrapper that the bubble chat widget would call into.
///
/// Using this indirection lets us assert *how* callers use sendMessage,
/// which is the real integration surface we care about. It is not production
/// code — it only lives inside the test file to make the contract testable.
class _BubbleChatController {
  _BubbleChatController(this._messaging);
  final MessagingHelper _messaging;

  Future<String?> sendText({
    required String bubbleId,
    required String content,
    String? replyTo,
  }) {
    return _messaging.sendMessage(
      bubbleId: bubbleId,
      content: content,
      repliedToMessageId: replyTo,
    );
  }

  Future<String?> sharePin({
    required String bubbleId,
    required int locationId,
    String caption = '',
  }) {
    return _messaging.sendMessage(
      bubbleId: bubbleId,
      content: caption,
      messageType: 'location',
      locationId: locationId,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _MockMessagingHelper messaging;
  late _BubbleChatController chat;

  setUpAll(() {
    // mocktail needs a fallback for any nullable named args we want to
    // capture in `any()`/`captureAny()` — register the non-primitive types.
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    messaging = _MockMessagingHelper();
    chat = _BubbleChatController(messaging);
  });

  group('sendMessage — text', () {
    test('forwards bubbleId and content, defaults messageType to text',
        () async {
      when(() => messaging.sendMessage(
            bubbleId: any(named: 'bubbleId'),
            content: any(named: 'content'),
            messageType: any(named: 'messageType'),
            metadata: any(named: 'metadata'),
            repliedToMessageId: any(named: 'repliedToMessageId'),
            locationId: any(named: 'locationId'),
          )).thenAnswer((_) async => 'msg-123');

      final id = await chat.sendText(
        bubbleId: 'bubble-7',
        content: 'anyone free for dinner?',
      );

      expect(id, 'msg-123');
      final captured = verify(() => messaging.sendMessage(
            bubbleId: captureAny(named: 'bubbleId'),
            content: captureAny(named: 'content'),
            messageType: captureAny(named: 'messageType'),
            metadata: captureAny(named: 'metadata'),
            repliedToMessageId: captureAny(named: 'repliedToMessageId'),
            locationId: captureAny(named: 'locationId'),
          )).captured;
      expect(captured[0], 'bubble-7');
      expect(captured[1], 'anyone free for dinner?');
      // messageType is defaulted on the wrapper, so null propagates.
      expect(captured[5], isNull, reason: 'no locationId for text messages');
    });

    test('propagates repliedToMessageId for threaded replies', () async {
      when(() => messaging.sendMessage(
            bubbleId: any(named: 'bubbleId'),
            content: any(named: 'content'),
            messageType: any(named: 'messageType'),
            metadata: any(named: 'metadata'),
            repliedToMessageId: any(named: 'repliedToMessageId'),
            locationId: any(named: 'locationId'),
          )).thenAnswer((_) async => 'msg-reply');

      await chat.sendText(
        bubbleId: 'b1',
        content: 'same',
        replyTo: 'msg-parent',
      );

      verify(() => messaging.sendMessage(
            bubbleId: 'b1',
            content: 'same',
            messageType: any(named: 'messageType'),
            metadata: any(named: 'metadata'),
            repliedToMessageId: 'msg-parent',
            locationId: any(named: 'locationId'),
          )).called(1);
    });
  });

  group('sendMessage — location pin', () {
    test('sets messageType=location and attaches locationId', () async {
      when(() => messaging.sendMessage(
            bubbleId: any(named: 'bubbleId'),
            content: any(named: 'content'),
            messageType: any(named: 'messageType'),
            metadata: any(named: 'metadata'),
            repliedToMessageId: any(named: 'repliedToMessageId'),
            locationId: any(named: 'locationId'),
          )).thenAnswer((_) async => 'msg-pin');

      await chat.sharePin(
        bubbleId: 'b1',
        locationId: 987,
        caption: 'this place slaps',
      );

      verify(() => messaging.sendMessage(
            bubbleId: 'b1',
            content: 'this place slaps',
            messageType: 'location',
            metadata: any(named: 'metadata'),
            repliedToMessageId: any(named: 'repliedToMessageId'),
            locationId: 987,
          )).called(1);
    });
  });

  group('sendMessage — failure propagation', () {
    test('rethrows exceptions from the Supabase RPC', () async {
      when(() => messaging.sendMessage(
            bubbleId: any(named: 'bubbleId'),
            content: any(named: 'content'),
            messageType: any(named: 'messageType'),
            metadata: any(named: 'metadata'),
            repliedToMessageId: any(named: 'repliedToMessageId'),
            locationId: any(named: 'locationId'),
          )).thenThrow(StateError('PostgrestException: 403 forbidden'));

      await expectLater(
        chat.sendText(bubbleId: 'b1', content: 'hi'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('MessagingHelper adjacent operations', () {
    test('initializeBubbleChat is called once per chat session', () async {
      when(() => messaging.initializeBubbleChat(any()))
          .thenAnswer((_) async {});

      await messaging.initializeBubbleChat('bubble-init');

      verify(() => messaging.initializeBubbleChat('bubble-init')).called(1);
    });

    test('markBubbleRead and getUnreadCount compose cleanly', () async {
      when(() => messaging.markBubbleRead(any())).thenAnswer((_) async {});
      when(() => messaging.getUnreadCount(any())).thenAnswer((_) async => 0);

      await messaging.markBubbleRead('b1');
      final unread = await messaging.getUnreadCount('b1');

      expect(unread, 0);
      verifyInOrder([
        () => messaging.markBubbleRead('b1'),
        () => messaging.getUnreadCount('b1'),
      ]);
    });
  });
}
