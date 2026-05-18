import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/widgets/referral_code_dialog.dart';

void main() {
  testWidgets('shows success state after applying a valid referral code',
      (tester) async {
    var viewedRewards = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReferralCodeDialog(
            onApply: (_) async => true,
            onDismiss: () async {},
            onViewRewards: () async {
              viewedRewards = true;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'pinit123');
    await tester.tap(find.text('Apply code'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Code applied'), findsOneWidget);
    expect(find.textContaining('Redeem it there'), findsOneWidget);
    expect(find.text('View rewards'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);

    await tester.tap(find.text('View rewards'));
    await tester.pump();

    expect(viewedRewards, isTrue);
  });
}
