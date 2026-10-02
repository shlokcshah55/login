import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/utils/photo_urls.dart';
import 'package:login/widgets/pinit_image.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  const cdn = 'https://img.example.com';

  tearDown(() => PhotoUrls.configure(null));

  testWidgets('null url shows the fallback, no network image', (tester) async {
    await _pump(tester, const PinitImage.location(url: null, width: 50));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.image), findsNothing);
  });

  testWidgets('location requests the variant for its size role',
      (tester) async {
    PhotoUrls.configure(cdn);
    await _pump(
      tester,
      const PinitImage.location(
        url: '$cdn/l/9/0_card.webp',
        size: PhotoSize.thumb,
        width: 80,
        height: 80,
      ),
    );
    final img = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(img.imageUrl, '$cdn/l/9/0_thumb.webp');
    expect(img.memCacheWidth, 320);
    expect(img.cacheManager, PinitImageCache.instance);
  });

  testWidgets('avatar asks the CDN for a dpr-scaled rendition', (tester) async {
    PhotoUrls.configure(cdn);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      const PinitImage.avatar(url: '$cdn/u/u1/p.jpg?v=2', diameter: 32),
    );
    final img = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(img.imageUrl,
        '$cdn/cdn-cgi/image/width=96,fit=cover,format=auto/u/u1/p.jpg?v=2');
    expect(img.memCacheWidth, 96);
  });

  testWidgets('non-cdn urls pass through untouched', (tester) async {
    const google = 'https://maps.googleapis.com/maps/api/place/photo?x=1';
    await _pump(
      tester,
      const PinitImage.location(url: google, width: 50, height: 50),
    );
    final img = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(img.imageUrl, google);
  });

  testWidgets('a failed cdn photo falls back to the Storage copy',
      (tester) async {
    PhotoUrls.configure(cdn, legacyBaseUrl: 'https://proj.supabase.co');
    await _pump(
      tester,
      const PinitImage.location(url: '$cdn/l/9/2_hero.webp', width: 80),
    );
    final img = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(img.imageUrl, '$cdn/l/9/2_card.webp');

    final context = tester.element(find.byType(CachedNetworkImage));
    final onError = img.errorWidget!(context, img.imageUrl, Exception('404'));
    expect(onError, isA<CachedNetworkImage>());
    final secondary = onError as CachedNetworkImage;
    expect(secondary.imageUrl,
        'https://proj.supabase.co/storage/v1/object/public/location_photos/9_2.jpg');
    expect(secondary.cacheManager, PinitImageCache.instance);

    // The Storage copy failing too ends at the quiet fallback.
    expect(secondary.errorWidget!(context, secondary.imageUrl, Exception()),
        isNot(isA<CachedNetworkImage>()));
  });
}
