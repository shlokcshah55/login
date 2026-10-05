import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:login/supabase/supabase_client.dart';
import 'package:login/utils/social_video_link.dart';

enum SocialIngestStatus {
  /// 202: the post was queued; the place arrives asynchronously.
  queued,
  invalidLink,
  notSignedIn,
  networkError,
  serverError,
}

class SocialIngestResult {
  const SocialIngestResult(this.status, {this.platform, this.message});

  final SocialIngestStatus status;
  final SocialVideoPlatform? platform;
  final String? message;

  bool get isQueued => status == SocialIngestStatus.queued;
}

/// Sends a pasted TikTok/Instagram link to the same endpoint, with the same
/// contract, as the iOS share extension (`ShareViewController.swift`). The
/// call only enqueues the post; results come back through the saved-locations
/// table and the `social_post_review` notification.
class SocialLinkIngestService {
  SocialLinkIngestService({http.Client? client, String? Function()? userId})
      : _client = client ?? http.Client(),
        _userId = userId ?? (() => SupabaseClientManager().currentUser?.id);

  static const String endpoint =
      'https://social-free-processor-299193903436.europe-west1.run.app/process-share';
  static const Duration timeout = Duration(seconds: 10);

  final http.Client _client;
  final String? Function() _userId;

  Future<SocialIngestResult> submit(String rawUrl) async {
    final link = SocialVideoLink.parse(rawUrl);
    if (link == null) {
      return const SocialIngestResult(
        SocialIngestStatus.invalidLink,
        message: 'That doesn’t look like a TikTok or Instagram Reel link.',
      );
    }
    final userId = _userId();
    if (userId == null || userId.isEmpty) {
      return const SocialIngestResult(SocialIngestStatus.notSignedIn);
    }

    try {
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'url': link.originalUrl, 'userId': userId}),
          )
          .timeout(timeout);

      if (response.statusCode == 202 || response.statusCode == 200) {
        return SocialIngestResult(
          SocialIngestStatus.queued,
          platform: link.platform,
        );
      }
      if (response.statusCode == 400) {
        return SocialIngestResult(
          SocialIngestStatus.invalidLink,
          message: _errorMessage(response.body),
        );
      }
      return SocialIngestResult(
        SocialIngestStatus.serverError,
        message: _errorMessage(response.body),
      );
    } on TimeoutException {
      return const SocialIngestResult(SocialIngestStatus.networkError);
    } catch (_) {
      return const SocialIngestResult(SocialIngestStatus.networkError);
    }
  }

  static String? _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {}
    return null;
  }
}
