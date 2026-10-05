import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/signup_wizard_state.dart';
import 'package:login/pages/signup_wizard/account_step.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onNext}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SignupWizardState(),
        child: MaterialApp(
          home: Scaffold(body: AccountStep(onNext: onNext ?? () {})),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('shows every field on one screen', (tester) async {
    await pump(tester);

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('USERNAME'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('submitting empty shows inline errors and does not continue',
      (tester) async {
    var advanced = false;
    await pump(tester, onNext: () => advanced = true);

    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Tell us what to call you'), findsOneWidget);
    expect(find.text('Pick a username'), findsOneWidget);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Choose a password'), findsOneWidget);
    expect(advanced, isFalse);
  });

  testWidgets('suggests a username from the name until it is edited',
      (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField).at(0), 'Sri Vitta');
    await tester.pump();

    final username = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(username.controller!.text, 'srivitta');
  });
}
