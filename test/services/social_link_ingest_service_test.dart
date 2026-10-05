import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login/services/social_link_ingest_service.dart';

void main() {
  const link = 'https://vm.tiktok.com/ZMabc123/';

  SocialLinkIngestService build(
    Future<http.Response> Function(http.Request) handler, {
    String? userId = 'user-1',
  }) =>
      SocialLinkIngestService(
        client: MockClient(handler),
        userId: () => userId,
      );

  test('202 is queued and sends url + userId like the share extension',
      () async {
    late http.Request captured;
    final service = build((request) async {
      captured = request;
      return http.Response('{"success":true}', 202);
    });

    final result = await service.submit(link);

    expect(result.isQueued, isTrue);
    expect(captured.url.toString(), SocialLinkIngestService.endpoint);
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['userId'], 'user-1');
    expect(body['url'], link);
  });

  test('rejects non TikTok/Instagram links without a network call', () async {
    var called = false;
    final service = build((request) async {
      called = true;
      return http.Response('', 202);
    });

    final result = await service.submit('https://example.com/x');

    expect(result.status, SocialIngestStatus.invalidLink);
    expect(called, isFalse);
  });

  test('requires a signed in user', () async {
    final service = build((_) async => http.Response('', 202), userId: null);
    final result = await service.submit(link);
    expect(result.status, SocialIngestStatus.notSignedIn);
  });

  test('400 surfaces the server error message', () async {
    final service = build(
      (_) async => http.Response('{"success":false,"error":"bad url"}', 400),
    );
    final result = await service.submit(link);
    expect(result.status, SocialIngestStatus.invalidLink);
    expect(result.message, 'bad url');
  });

  test('500 is a server error and exceptions are network errors', () async {
    final server = build((_) async => http.Response('oops', 500));
    expect((await server.submit(link)).status, SocialIngestStatus.serverError);

    final network = build((_) async => throw http.ClientException('offline'));
    expect(
      (await network.submit(link)).status,
      SocialIngestStatus.networkError,
    );

    // The real 10s timeout is too slow for a unit test; a thrown
    // TimeoutException is handled identically.
    final thrown = build((_) async => throw TimeoutException('slow'));
    expect(
      (await thrown.submit(link)).status,
      SocialIngestStatus.networkError,
    );
  });
}
