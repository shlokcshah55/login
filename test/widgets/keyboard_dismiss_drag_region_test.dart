import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/widgets/keyboard_dismiss_drag_region.dart';

void main() {
  testWidgets('downward swipe dismisses a focused text field', (tester) async {
    await tester.pumpWidget(const _KeyboardDismissHarness());

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.drag(find.byKey(const Key('dismiss_surface')), const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(editableText.focusNode.hasFocus, isFalse);
  });

  testWidgets('upward swipe keeps the keyboard focused', (tester) async {
    await tester.pumpWidget(const _KeyboardDismissHarness());

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.drag(
      find.byKey(const Key('dismiss_surface')),
      const Offset(0, -40),
    );
    await tester.pumpAndSettle();

    expect(editableText.focusNode.hasFocus, isTrue);
  });
}

class _KeyboardDismissHarness extends StatelessWidget {
  const _KeyboardDismissHarness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: KeyboardDismissDragRegion(
        child: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(),
              ),
              Expanded(
                child: Container(
                  key: const Key('dismiss_surface'),
                  color: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
