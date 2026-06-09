import 'package:flutter_test/flutter_test.dart';
import 'package:login/utils/social_video_link.dart';

void main() {
  group('SocialVideoLink', () {
    test('normalizes TikTok video links and strips tracking params', () {
      final link = SocialVideoLink.parse(
        ' https://www.tiktok.com/@chef/video/123?is_from_webapp=1&sender=abc ',
      );

      expect(link, isNotNull);
      expect(link!.platform, SocialVideoPlatform.tiktok);
      expect(link.normalizedUrl, 'https://www.tiktok.com/@chef/video/123');
    });

    test('normalizes TikTok short links without resolving them', () {
      final link = SocialVideoLink.parse('https://vm.tiktok.com/ZNRb3SMLF/');

      expect(link, isNotNull);
      expect(link!.platform, SocialVideoPlatform.tiktok);
      expect(link.normalizedUrl, 'https://vm.tiktok.com/ZNRb3SMLF/');
    });

    test('normalizes Instagram Reel links', () {
      final link = SocialVideoLink.parse(
        'https://www.instagram.com/reel/ABC123/?igsh=tracking',
      );

      expect(link, isNotNull);
      expect(link!.platform, SocialVideoPlatform.instagram);
      expect(link.normalizedUrl, 'https://www.instagram.com/reel/ABC123/');
    });

    test('rejects unsupported social links', () {
      expect(SocialVideoLink.parse('https://youtube.com/shorts/123'), isNull);
    });
  });
}
