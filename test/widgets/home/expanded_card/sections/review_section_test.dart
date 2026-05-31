import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_card/sections/review_section.dart';

void main() {
  LocationModel buildLocation({List<Map<String, dynamic>>? reviews}) {
    return LocationModel(
      locationId: 1,
      name: 'Test place',
      createdAt: DateTime(2026, 1, 1),
      reviews: reviews,
    );
  }

  Widget buildSubject({
    LocationModel? location,
    List<Map<String, dynamic>> pinitReviews = const [],
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReviewSection(
            location: location ?? buildLocation(),
            pinitReviews: pinitReviews,
          ),
        ),
      ),
    );
  }

  testWidgets('tapping a Pinit review opens the full review', (tester) async {
    const reviewText =
        'The upstairs table by the window is the one to ask for, and the '
        'charred aubergine starter was much better than the photos suggested.';

    await tester.pumpWidget(
      buildSubject(
        pinitReviews: [
          {
            'user_id': 'user-1',
            'content': reviewText,
            'rating': 9,
            'created_at': '2026-01-01T12:00:00Z',
            'users': {'name': 'Priya'},
          },
        ],
      ),
    );

    await tester.tap(find.text(reviewText));
    await tester.pumpAndSettle();

    expect(find.text('Full review'), findsOneWidget);
    expect(find.text(reviewText), findsNWidgets(2));
  });

  testWidgets('tapping a Google review opens the full review', (tester) async {
    const reviewText =
        'A proper neighbourhood spot with generous portions, warm service, '
        'and enough detail in this review to need a full-reading state.';

    await tester.pumpWidget(
      buildSubject(
        location: buildLocation(
          reviews: [
            {
              'author_name': 'Sam',
              'rating': 5,
              'text': reviewText,
              'time': 1767225600,
            },
          ],
        ),
      ),
    );

    await tester.tap(find.text(reviewText));
    await tester.pumpAndSettle();

    expect(find.text('Full review'), findsOneWidget);
    expect(find.text(reviewText), findsNWidgets(2));
  });
}
