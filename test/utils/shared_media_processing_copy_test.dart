import 'package:flutter_test/flutter_test.dart';
import 'package:login/utils/shared_media_processing_copy.dart';

void main() {
  group('buildSharedMediaProcessingErrorCopy', () {
    test('uses TikTok wording for missing location information', () {
      final copy = buildSharedMediaProcessingErrorCopy(
        errorType: 'not_enough_location_info',
        sourceUrl: 'https://www.tiktok.com/@chef/video/123',
      );

      expect(copy.title, "Couldn't find a place in this TikTok");
      expect(
        copy.body,
        "The video didn't include enough location detail. You can search for the place and add it manually.",
      );
    });

    test('uses Reel wording for Instagram source URLs', () {
      final copy = buildSharedMediaProcessingErrorCopy(
        errorType: 'not_enough_location_info',
        sourceUrl: 'https://www.instagram.com/reel/abc123/',
      );

      expect(copy.title, "Couldn't find a place in this Reel");
      expect(
        copy.body,
        "The reel didn't include enough location detail. You can search for the place and add it manually.",
      );
    });

    test('explains unsupported links', () {
      final copy = buildSharedMediaProcessingErrorCopy(
        errorType: 'unsupported_link',
        sourceUrl: 'https://example.com/video/123',
      );

      expect(copy.title, "This link isn't supported yet");
      expect(
          copy.body, 'Pinit can process TikToks and Instagram Reels for now.');
    });

    test('keeps a safe fallback for unknown failures', () {
      final copy = buildSharedMediaProcessingErrorCopy(errorType: 'unknown');

      expect(copy.title, "Couldn't process this video");
      expect(
        copy.body,
        'Something went wrong while processing it. Try again or add the place manually.',
      );
    });
  });
}
