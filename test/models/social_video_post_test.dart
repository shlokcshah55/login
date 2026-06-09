import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/video_insights.dart';

void main() {
  test('uses Reel fallback label for Instagram posts without a creator', () {
    const post = SocialVideoPost(
      sourceVideoUrl: 'https://www.instagram.com/reel/ABC123/',
    );

    expect(post.displayHandle, 'Reel');
  });

  test('keeps TikTok fallback label for TikTok posts without a creator', () {
    const post = SocialVideoPost(
      sourceVideoUrl: 'https://www.tiktok.com/@chef/video/123',
    );

    expect(post.displayHandle, 'TikTok creator');
  });
}
