import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';

void main() {
  test('parses shared TikTok metadata from location rows', () {
    final location = LocationModel.fromJson(
      {
        'location_id': 42,
        'name': 'Noodle Yard',
        'created_at': '2026-04-30T12:00:00Z',
        'social_video_count': 3,
        'social_video_url': 'https://www.tiktok.com/@chef/video/123',
        'social_video_creator_handle': 'chef',
        'tiktok_recommended_dish': 'chilli oil noodles',
      },
      null,
    );

    expect(location.socialVideoCount, 3);
    expect(location.socialVideoUrl, 'https://www.tiktok.com/@chef/video/123');
    expect(location.socialVideoCreatorHandle, 'chef');
    expect(location.tiktokRecommendedDish, 'chilli oil noodles');
    expect(location.hasSocialVideos, isTrue);
  });

  test('copyWith preserves shared TikTok metadata by default', () {
    final location = LocationModel(
      locationId: 42,
      name: 'Noodle Yard',
      createdAt: DateTime.utc(2026, 4, 30),
      socialVideoCount: 4,
      socialVideoUrl: 'https://www.tiktok.com/@chef/video/123',
      socialVideoCreatorHandle: 'chef',
      tiktokRecommendedDish: 'chilli oil noodles',
    );

    final copy = location.copyWith(name: 'Noodle Yard Soho');

    expect(copy.socialVideoCount, 4);
    expect(copy.socialVideoUrl, location.socialVideoUrl);
    expect(copy.socialVideoCreatorHandle, location.socialVideoCreatorHandle);
    expect(copy.tiktokRecommendedDish, location.tiktokRecommendedDish);
  });
}
