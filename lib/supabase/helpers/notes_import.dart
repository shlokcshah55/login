import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_client.dart';

class NotesImportException implements Exception {
  final String message;
  const NotesImportException(this.message);

  @override
  String toString() => message;
}

class NotesImportResult {
  final bool success;
  final bool queued;
  final String message;
  final int extractedCount;
  final int matchedCount;
  final int savedCount;
  final int alreadySavedCount;
  final int saveFailedCount;
  final bool truncatedInput;
  final String sourceName;
  final List<Map<String, dynamic>> savedLocations;
  final List<Map<String, dynamic>> skippedLocations;
  final List<Map<String, dynamic>> unmatchedLocations;

  const NotesImportResult({
    required this.success,
    required this.queued,
    required this.message,
    required this.extractedCount,
    required this.matchedCount,
    required this.savedCount,
    required this.alreadySavedCount,
    required this.saveFailedCount,
    required this.truncatedInput,
    required this.sourceName,
    required this.savedLocations,
    required this.skippedLocations,
    required this.unmatchedLocations,
  });

  factory NotesImportResult.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> _parseList(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return NotesImportResult(
      success: json['success'] == true,
      queued: json['queued'] == true,
      message: (json['message'] as String?) ?? '',
      extractedCount: (json['extracted_count'] as num?)?.toInt() ?? 0,
      matchedCount: (json['matched_count'] as num?)?.toInt() ?? 0,
      savedCount: (json['saved_count'] as num?)?.toInt() ?? 0,
      alreadySavedCount: (json['already_saved_count'] as num?)?.toInt() ?? 0,
      saveFailedCount: (json['save_failed_count'] as num?)?.toInt() ?? 0,
      truncatedInput: json['truncated_input'] == true,
      sourceName: (json['source_name'] as String?) ?? 'Imported note',
      savedLocations: _parseList('saved_locations'),
      skippedLocations: _parseList('skipped_locations'),
      unmatchedLocations: _parseList('unmatched_locations'),
    );
  }
}

class NotesImportHelper {
  static const String _importEndpoint =
      'https://notes-import-jkqbw4i75a-ew.a.run.app/import-notes';

  final SupabaseClient _client = SupabaseClientManager().client;
  final http.Client _http;

  NotesImportHelper({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Future<NotesImportResult> importText({
    required String userId,
    required String text,
    String? sourceName,
  }) async {
    final session = _requireSession();
    debugPrint('[NotesImportHelper] POST $_importEndpoint (text)');
    final response = await _http
        .post(
          Uri.parse(_importEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({
            'user_id': userId,
            'text': text,
            if (sourceName != null && sourceName.trim().isNotEmpty)
              'source_name': sourceName.trim(),
          }),
        )
        .timeout(const Duration(seconds: 120));

    return _parseResponse(response);
  }

  Future<NotesImportResult> importFile({
    required String userId,
    required PlatformFile file,
    String? sourceName,
  }) async {
    final session = _requireSession();
    final uri = Uri.parse(_importEndpoint);
    debugPrint('[NotesImportHelper] POST $uri (file: ${file.name})');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..fields['user_id'] = userId;

    if (sourceName != null && sourceName.trim().isNotEmpty) {
      request.fields['source_name'] = sourceName.trim();
    }

    final bytes = _requireFileBytes(file);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
      ),
    );

    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamed);
    return _parseResponse(response);
  }

  Session _requireSession() {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw const NotesImportException('Not logged in');
    }
    return session;
  }

  Uint8List _requireFileBytes(PlatformFile file) {
    if (file.bytes != null) {
      return file.bytes!;
    }
    throw const NotesImportException(
      'Could not read the selected file. Try exporting it again.',
    );
  }

  NotesImportResult _parseResponse(http.Response response) {
    Map<String, dynamic> decoded = const {};
    if (response.body.isNotEmpty) {
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        }
      } on FormatException {
        decoded = {
          'error': response.body,
        };
      }
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const NotesImportException(
        'Authentication failed. Please log in again.',
      );
    }

    if (response.statusCode == 400 || response.statusCode == 422) {
      throw NotesImportException(
        decoded['error'] as String? ?? 'Import failed',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NotesImportException(
        decoded['error'] as String? ?? 'Could not import your note right now.',
      );
    }

    return NotesImportResult.fromJson(decoded);
  }
}
