import 'package:login/utils/social_video_link.dart';

class SharedMediaProcessingErrorCopy {
  const SharedMediaProcessingErrorCopy({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

SharedMediaProcessingErrorCopy buildSharedMediaProcessingErrorCopy({
  String? errorType,
  String? platform,
  String? sourceUrl,
}) {
  final type = (errorType ?? '').trim().toLowerCase();
  final media =
      _SharedMediaLabel.from(platform: platform, sourceUrl: sourceUrl);

  switch (type) {
    case 'not_enough_location_info':
    case 'insufficient_location_info':
    case 'no_location_found':
      return SharedMediaProcessingErrorCopy(
        title: "Couldn't find a place in this ${media.singularLabel}",
        body:
            "The ${media.bodyLabel} didn't include enough location detail. You can search for the place and add it manually.",
      );
    case 'unsupported_link':
    case 'unsupported_url':
      return const SharedMediaProcessingErrorCopy(
        title: "This link isn't supported yet",
        body: 'Pinit can process TikToks and Instagram Reels for now.',
      );
    case 'private_or_unavailable':
    case 'unavailable':
    case 'private':
      return const SharedMediaProcessingErrorCopy(
        title: "This video isn't available",
        body: 'It may be private, deleted, or blocked from processing.',
      );
    case 'network_error':
    case 'processing_timeout':
    case 'timeout':
    case 'unknown':
    case '':
      return const SharedMediaProcessingErrorCopy(
        title: "Couldn't process this video",
        body:
            'Something went wrong while processing it. Try again or add the place manually.',
      );
    default:
      return const SharedMediaProcessingErrorCopy(
        title: "Couldn't process this video",
        body:
            'Something went wrong while processing it. Try again or add the place manually.',
      );
  }
}

class _SharedMediaLabel {
  const _SharedMediaLabel({
    required this.singularLabel,
    required this.bodyLabel,
  });

  final String singularLabel;
  final String bodyLabel;

  static _SharedMediaLabel from({
    String? platform,
    String? sourceUrl,
  }) {
    final detected = socialVideoPlatformFrom(
      platform: platform,
      sourceUrl: sourceUrl,
    );
    switch (detected) {
      case SocialVideoPlatform.tiktok:
        return const _SharedMediaLabel(
          singularLabel: 'TikTok',
          bodyLabel: 'video',
        );
      case SocialVideoPlatform.instagram:
        return const _SharedMediaLabel(
          singularLabel: 'Reel',
          bodyLabel: 'reel',
        );
      case null:
        return const _SharedMediaLabel(
          singularLabel: 'video',
          bodyLabel: 'video',
        );
    }
  }
}
