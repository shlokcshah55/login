import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_card/helpers/social_video_source.dart';

void main() {
  LocationModel buildLocation({
    String? savedFrom,
    String? socialVideoUrl,
    int socialVideoCount = 0,
  }) {
    return LocationModel(
      locationId: 42,
      name: 'Noodle Yard',
      createdAt: DateTime.utc(2026, 5, 14),
      savedFrom: savedFrom,
      socialVideoUrl: socialVideoUrl,
      socialVideoCount: socialVideoCount,
    );
  }

  test('prefers savedFrom when expanded card opens from saved locations', () {
    final location = buildLocation(
      savedFrom: ' https://www.tiktok.com/@saved/video/1 ',
      socialVideoUrl: 'https://www.tiktok.com/@public/video/2',
      socialVideoCount: 2,
    );

    expect(
      preferredExpandedCardSocialVideoUrl(location),
      'https://www.tiktok.com/@saved/video/1',
    );
  });

  test('falls back to public social video url when savedFrom is unavailable',
      () {
    final location = buildLocation(
      socialVideoUrl: ' https://www.tiktok.com/@public/video/2 ',
      socialVideoCount: 2,
    );

    expect(
      preferredExpandedCardSocialVideoUrl(location),
      'https://www.tiktok.com/@public/video/2',
    );
  });

  test('resolves on open when social context exists but url is missing', () {
    final location = buildLocation(socialVideoCount: 3);

    expect(
      shouldResolveExpandedCardSocialVideoUrl(
        location,
        forceResolveOnOpen: false,
      ),
      isTrue,
    );
  });

  test('does not resolve on open when no social context exists', () {
    final location = buildLocation();

    expect(
      shouldResolveExpandedCardSocialVideoUrl(
        location,
        forceResolveOnOpen: false,
      ),
      isFalse,
    );
  });
}
