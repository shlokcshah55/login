import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/message.dart';
import 'package:login/pages/bubble_messaging_page.dart';
import 'package:login/providers/messaging_provider.dart';
import 'package:login/supabase/helpers/messaging.dart';

void main() {
  testWidgets('conversation switcher shows messages tab without a count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = _TestMessagingProvider(
      messages: [
        MessageModel(
          id: 'message-1',
          bubbleId: 'bubble-1',
          senderId: 'user-1',
          senderName: 'Alex',
          senderAvatarUrl: '',
          content: 'First message',
          messageType: 'text',
          createdAt: DateTime(2026, 5, 14),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BubbleMessagingPage(
          bubble: Bubble(
            id: 'bubble-1',
            name: 'Weekend Plans',
            createdBy: 'user-1',
            lastMessage: 'First message',
            lastMessageTime: 'now',
            memberCount: 3,
            memberAvatars: const [],
            groupAvatar: '',
          ),
          provider: provider,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('MESSAGES'), findsOneWidget);
    expect(find.text('1 messages'), findsNothing);
  });

  testWidgets('message list separates messages by local date', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final currentYear = DateTime.now().year;

    final provider = _TestMessagingProvider(
      messages: [
        MessageModel(
          id: 'message-1',
          bubbleId: 'bubble-1',
          senderId: 'user-1',
          senderName: 'Alex',
          senderAvatarUrl: '',
          content: 'Friday plan',
          messageType: 'text',
          createdAt: DateTime(currentYear, 5, 15, 10),
        ),
        MessageModel(
          id: 'message-2',
          bubbleId: 'bubble-1',
          senderId: 'user-2',
          senderName: 'Sam',
          senderAvatarUrl: '',
          content: 'Thursday idea',
          messageType: 'text',
          createdAt: DateTime(currentYear, 5, 14, 20),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BubbleMessagingPage(
          bubble: Bubble(
            id: 'bubble-1',
            name: 'Weekend Plans',
            createdBy: 'user-1',
            lastMessage: 'Friday plan',
            lastMessageTime: 'now',
            memberCount: 3,
            memberAvatars: const [],
            groupAvatar: '',
          ),
          provider: provider,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('May 15'), findsOneWidget);
    expect(find.text('May 14'), findsOneWidget);
  });

  testWidgets('typing @ shows members and inserts a mention', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = _TestMessagingProvider(messages: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: BubbleMessagingPage(
          bubble: Bubble(
            id: 'bubble-1',
            name: 'Weekend Plans',
            createdBy: 'user-1',
            lastMessage: '',
            lastMessageTime: 'now',
            memberCount: 3,
            memberAvatars: const ['', '', ''],
            groupAvatar: '',
            memberIds: const ['user-1', 'user-2', 'user-3'],
            memberNames: const ['Alex', 'Sam', 'Taylor'],
          ),
          provider: provider,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Meet @');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mention_suggestion_user-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mention_suggestion_user-2')));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, 'Meet @Sam ');
  });

  testWidgets('dragging the chat list dismisses the composer focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = _TestMessagingProvider(
      messages: List.generate(
        20,
        (index) => MessageModel(
          id: 'message-$index',
          bubbleId: 'bubble-1',
          senderId: index.isEven ? 'user-1' : 'user-2',
          senderName: index.isEven ? 'Alex' : 'Sam',
          senderAvatarUrl: '',
          content: 'Message $index',
          messageType: 'text',
          createdAt: DateTime(2026, 5, 14, 12, index),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BubbleMessagingPage(
          bubble: Bubble(
            id: 'bubble-1',
            name: 'Weekend Plans',
            createdBy: 'user-1',
            lastMessage: 'First message',
            lastMessageTime: 'now',
            memberCount: 3,
            memberAvatars: const [],
            groupAvatar: '',
          ),
          provider: provider,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(editableText.focusNode.hasFocus, isFalse);
  });

  testWidgets('initial pins view shows only pinned messages', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = _TestMessagingProvider(
      messages: [
        MessageModel(
          id: 'message-1',
          bubbleId: 'bubble-1',
          senderId: 'user-2',
          senderName: 'Sam',
          senderAvatarUrl: '',
          content: 'Plain text',
          messageType: 'text',
          createdAt: DateTime(2026, 5, 14),
        ),
        MessageModel(
          id: 'message-2',
          bubbleId: 'bubble-1',
          senderId: 'user-2',
          senderName: 'Sam',
          senderAvatarUrl: '',
          content: 'Pin drop',
          messageType: 'text',
          locationId: 42,
          createdAt: DateTime(2026, 5, 14, 0, 1),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BubbleMessagingPage(
          bubble: Bubble(
            id: 'bubble-1',
            name: 'Weekend Plans',
            createdBy: 'user-1',
            lastMessage: 'Pin drop',
            lastMessageTime: 'now',
            memberCount: 3,
            memberAvatars: const [],
            groupAvatar: '',
          ),
          provider: provider,
          initialView: BubbleMessageView.pins,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('1 PINS'), findsOneWidget);
    expect(find.text('Pin drop'), findsOneWidget);
    expect(find.text('Plain text'), findsNothing);
  });

  testWidgets('tapping a sender avatar opens that user profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? openedUserId;
    final provider = _TestMessagingProvider(
      messages: [
        MessageModel(
          id: 'message-1',
          bubbleId: 'bubble-1',
          senderId: 'user-2',
          senderName: 'Sam',
          senderAvatarUrl: '',
          content: 'Hey there',
          messageType: 'text',
          createdAt: DateTime(2026, 5, 14),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BubbleMessagingPage(
          bubble: Bubble(
            id: 'bubble-1',
            name: 'Weekend Plans',
            createdBy: 'user-1',
            lastMessage: 'Hey there',
            lastMessageTime: 'now',
            memberCount: 3,
            memberAvatars: const [],
            groupAvatar: '',
          ),
          provider: provider,
          onOpenUserProfile: (userId) async {
            openedUserId = userId;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('message_avatar_message-1')));
    await tester.pumpAndSettle();

    expect(openedUserId, 'user-2');
  });
}

class _TestMessagingProvider extends MessagingProvider {
  _TestMessagingProvider({required List<MessageModel> messages})
      : _messages = messages,
        super(
          bubbleId: 'bubble-1',
          messagingHelper: _FakeMessagingHelper(),
        );

  final List<MessageModel> _messages;

  @override
  List<MessageModel> get messages => _messages;

  @override
  bool get isLoading => false;

  @override
  bool get isLoadingMore => false;

  @override
  bool get isSending => false;

  @override
  bool get hasMore => false;

  @override
  String? get error => null;

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadMoreMessages() async {}

  @override
  Future<bool> sendMessage(
    String content, {
    String? replyToId,
    int? locationId,
  }) async =>
      true;

  @override
  void dispose() {
    super.dispose();
  }
}

class _FakeMessagingHelper implements MessagingHelper {
  @override
  void unsubscribeFromMessages() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
