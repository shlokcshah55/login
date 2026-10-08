import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/signup_wizard/signup_intro_video_page.dart';

void main() {
  const duration = Duration(milliseconds: 31500);

  group('chapterFills', () {
    test('is all empty before the video has a duration', () {
      final fills = chapterFills(
        position: Duration.zero,
        duration: Duration.zero,
      );
      expect(fills, hasLength(9));
      expect(fills, everyElement(0.0));
    });

    test('fills earlier chapters and part of the current one', () {
      // Halfway through "Share it to Pinit" (2.6s to 7.6s).
      final fills = chapterFills(
        position: const Duration(milliseconds: 5100),
        duration: duration,
      );
      expect(fills[0], 1.0);
      expect(fills[1], closeTo(0.5, 0.001));
      expect(fills.skip(2), everyElement(0.0));
    });

    test('is all full at the end', () {
      final fills = chapterFills(position: duration, duration: duration);
      expect(fills, everyElement(1.0));
    });

    test('falls back to one segment if the video length changes', () {
      final fills = chapterFills(
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 40),
      );
      expect(fills, [0.25]);
    });
  });
}
