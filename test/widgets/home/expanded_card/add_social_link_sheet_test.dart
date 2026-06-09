import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/widgets/home/expanded_card/add_social_link_sheet.dart';

void main() {
  Widget buildSubject({
    required Future<bool> Function(String url) onSave,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AddSocialLinkSheet(
          locationName: 'Noodle Yard',
          onSave: onSave,
        ),
      ),
    );
  }

  testWidgets('keeps save disabled for unsupported links', (tester) async {
    await tester.pumpWidget(
      buildSubject(onSave: (_) async => true),
    );

    await tester.enterText(
      find.byKey(const Key('social_link_input')),
      'https://youtube.com/shorts/123',
    );
    await tester.pump();

    expect(find.text('Paste a TikTok or Instagram Reel link.'), findsOneWidget);
    final save = tester.widget<ElevatedButton>(
      find.byKey(const Key('social_link_save')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('saves a valid Instagram Reel link', (tester) async {
    String? savedUrl;
    await tester.pumpWidget(
      buildSubject(
        onSave: (url) async {
          savedUrl = url;
          return true;
        },
      ),
    );

    await tester.enterText(
      find.byKey(const Key('social_link_input')),
      'https://www.instagram.com/reel/ABC123/?igsh=tracking',
    );
    await tester.pump();

    expect(find.text('Instagram Reel'), findsOneWidget);
    await tester.tap(find.byKey(const Key('social_link_save')));
    await tester.pump();

    expect(savedUrl, 'https://www.instagram.com/reel/ABC123/');
  });
}
