import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  testWidgets('shows equivalent social post urls only once', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const [
          SocialVideoPost(
            sourceVideoUrl: 'https://www.tiktok.com/@chef/video/123',
            creatorHandle: 'chef',
          ),
          SocialVideoPost(
            sourceVideoUrl:
                ' https://www.tiktok.com/@chef/video/123?lang=en&utm_source=copy ',
            creatorHandle: 'duplicatechef',
          ),
        ],
      ),
    );

    expect(find.text('1 shared post from this place'), findsOneWidget);
    expect(find.text('@chef'), findsOneWidget);
    expect(find.text('@duplicatechef'), findsNothing);
  });

  testWidgets('labels social post cards by platform', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const [
          SocialVideoPost(
            sourceVideoUrl: 'https://www.tiktok.com/@chef/video/123',
          ),
          SocialVideoPost(
            sourceVideoUrl: 'https://www.instagram.com/reel/ABC123/',
          ),
        ],
      ),
    );

    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
  });

  testWidgets('renders TikTok cards with the TikTok SVG mark', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const [
          SocialVideoPost(
            sourceVideoUrl: 'https://www.tiktok.com/@chef/video/123',
          ),
        ],
      ),
    );

    expect(find.byType(SvgPicture), findsWidgets);
  });

  testWidgets('keeps the large TikTok SVG mark compact', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const [
          SocialVideoPost(
            sourceVideoUrl: 'https://www.tiktok.com/@chef/video/123',
          ),
        ],
      ),
    );

    final firstSvg = find.byType(SvgPicture).first;
    expect(tester.getSize(firstSvg), const Size.square(20));
  });
}
