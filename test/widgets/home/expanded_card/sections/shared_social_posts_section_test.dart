import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/video_insights.dart';
import 'package:login/widgets/home/expanded_card/sections/shared_social_posts_section.dart';

void main() {
  Widget buildSubject(List<SocialVideoPost> posts) {
    return MaterialApp(
      home: Scaffold(
        body: SharedSocialPostsSection(
          posts: posts,
          onPostTap: (_) {},
        ),
      ),
    );
  }

  testWidgets('uses social-video header for Instagram-only posts',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const [
          SocialVideoPost(
            sourceVideoUrl: 'https://www.instagram.com/reel/ABC123/',
          ),
        ],
      ),
    );

    expect(find.text('Seen on Socials'), findsOneWidget);
    expect(find.text('Seen on TikTok'), findsNothing);
  });

  testWidgets('keeps TikTok header for TikTok-only posts', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const [
          SocialVideoPost(
            sourceVideoUrl: 'https://www.tiktok.com/@chef/video/123',
          ),
        ],
      ),
    );

    expect(find.text('Seen on TikTok'), findsOneWidget);
  });
}
