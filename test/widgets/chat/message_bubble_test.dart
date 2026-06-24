import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/message.dart';
import 'package:login/widgets/chat/message_bubble.dart';

void main() {
  testWidgets('renders @ mentions in bold', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: MessageModel(
              id: 'message-1',
              bubbleId: 'bubble-1',
              senderId: 'user-2',
              senderName: 'Alex',
              senderAvatarUrl: '',
              content: 'Meet @Sam at 8',
              messageType: 'text',
              createdAt: DateTime(2026, 5, 14),
            ),
            isFromCurrentUser: false,
          ),
        ),
      ),
    );

    final richText = tester.widget<Text>(
      find.byKey(const Key('message_content_message-1')),
    );
    final spans = _flattenTextSpans(richText.textSpan! as TextSpan);
    final mentionSpan = spans.singleWhere((span) => span.text == '@Sam');

    expect(mentionSpan.style?.fontWeight, FontWeight.w900);
    expect(
      mentionSpan.style?.fontVariations,
      contains(const FontVariation('wght', 900)),
    );
  });
}

List<TextSpan> _flattenTextSpans(TextSpan span) {
  return [
    if (span.text != null) span,
    for (final child in span.children ?? const <InlineSpan>[])
      if (child is TextSpan) ..._flattenTextSpans(child),
  ];
}
