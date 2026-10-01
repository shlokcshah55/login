import 'package:flutter_test/flutter_test.dart';
import 'package:login/utils/photo_urls.dart';

void main() {
  const cdn = 'https://img.example.com';
  const legacy = 'https://abc.supabase.co/storage/v1/object/public';

  tearDown(() => PhotoUrls.configure(null));

  group('unconfigured', () {
    test('is a no-op', () {
      expect(PhotoUrls.isConfigured, isFalse);
      expect(PhotoUrls.location('id', PhotoSize.card), isNull);
      const url = '$legacy/profile_photos/u1/a.jpg?v=1';
      expect(PhotoUrls.normalize(url), url);
      expect(PhotoUrls.avatar(url, 96), url);
    });
  });

  group('configured', () {
    setUp(() => PhotoUrls.configure('$cdn/'));

    test('builds location variant urls', () {
      expect(PhotoUrls.location('abc', PhotoSize.thumb),
          '$cdn/l/abc/0_thumb.webp');
      expect(PhotoUrls.location('abc', PhotoSize.hero, index: 3),
          '$cdn/l/abc/3_hero.webp');
    });

    test('normalizes legacy location urls incl. extras and png', () {
      expect(PhotoUrls.normalize('$legacy/location_photos/abc.jpg'),
          '$cdn/l/abc/0_card.webp');
      expect(
          PhotoUrls.normalize('$legacy/location_photos/abc_4.png',
              fallbackSize: PhotoSize.hero),
          '$cdn/l/abc/4_hero.webp');
    });

    test('normalizes legacy profile and cover urls, keeping the cache buster',
        () {
      expect(PhotoUrls.normalize('$legacy/profile_photos/u1/p.jpg?v=99'),
          '$cdn/u/u1/p.jpg?v=99');
      expect(PhotoUrls.normalize('$legacy/collection_covers/c1/cover.png'),
          '$cdn/c/c1/cover.png');
    });

    test('variant swaps the size role only on cdn variant urls', () {
      expect(PhotoUrls.variant('$cdn/l/abc/2_card.webp', PhotoSize.thumb),
          '$cdn/l/abc/2_thumb.webp');
      const google = 'https://maps.googleapis.com/maps/api/place/photo?x=1';
      expect(PhotoUrls.variant(google, PhotoSize.thumb), google);
      expect(PhotoUrls.variant(null, PhotoSize.thumb), isNull);
    });

    test('leaves foreign urls alone', () {
      const google = 'https://maps.googleapis.com/maps/api/place/photo?x=1';
      expect(PhotoUrls.normalize(google), google);
      expect(PhotoUrls.avatar(google, 96), google);
    });

    test('avatar wraps cdn urls in a transformation', () {
      expect(PhotoUrls.avatar('$legacy/profile_photos/u1/p.jpg?v=9', 96),
          '$cdn/cdn-cgi/image/width=96,fit=cover,format=auto/u/u1/p.jpg?v=9');
    });
  });
}
