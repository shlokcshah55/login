import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/widgets/onboarding/spotlight_wizard_overlay.dart';

void main() {
  testWidgets('advances through spotlight steps and completes', (tester) async {
    final firstKey = GlobalKey();
    final secondKey = GlobalKey();
    var completed = false;

    await tester.pumpWidget(
      _SpotlightHarness(
        firstKey: firstKey,
        secondKey: secondKey,
        onCompleted: () => completed = true,
      ),
    );
    await tester.pump();

    expect(find.text('First target'), findsOneWidget);
    expect(find.text('PIN 1 OF 2'), findsOneWidget);

    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    expect(find.text('Second target'), findsOneWidget);
    expect(find.text('PIN 2 OF 2'), findsOneWidget);

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  testWidgets('skip callback closes the tour path', (tester) async {
    final firstKey = GlobalKey();
    final secondKey = GlobalKey();
    var skipped = false;

    await tester.pumpWidget(
      _SpotlightHarness(
        firstKey: firstKey,
        secondKey: secondKey,
        onSkipped: () => skipped = true,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();

    expect(skipped, isTrue);
  });
}

class _SpotlightHarness extends StatelessWidget {
  const _SpotlightHarness({
    required this.firstKey,
    required this.secondKey,
    this.onCompleted,
    this.onSkipped,
  });

  final GlobalKey firstKey;
  final GlobalKey secondKey;
  final VoidCallback? onCompleted;
  final VoidCallback? onSkipped;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: 80,
              left: 24,
              child: SizedBox(
                key: firstKey,
                width: 180,
                height: 52,
                child: const ColoredBox(color: Colors.red),
              ),
            ),
            Positioned(
              right: 24,
              bottom: 120,
              child: SizedBox(
                key: secondKey,
                width: 120,
                height: 48,
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
            SpotlightWizardOverlay(
              steps: [
                SpotlightWizardStep(
                  targetKey: firstKey,
                  title: 'First target',
                  description: 'This is the first target.',
                ),
                SpotlightWizardStep(
                  targetKey: secondKey,
                  title: 'Second target',
                  description: 'This is the second target.',
                ),
              ],
              onCompleted: onCompleted ?? () {},
              onSkipped: onSkipped ?? () {},
            ),
          ],
        ),
      ),
    );
  }
}
