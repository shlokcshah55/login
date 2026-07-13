import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:login/services/startup_cache/startup_snapshot.dart';
import 'package:path_provider/path_provider.dart';

enum StartupSnapshotReadStatus {
  hit,
  miss,
  corrupt,
  unsupportedSchema,
  ownershipMismatch,
  tooLarge,
}

class StartupSnapshotReadResult {
  const StartupSnapshotReadResult({
    required this.status,
    this.snapshot,
    this.byteSize = 0,
  });

  final StartupSnapshotReadStatus status;
  final StartupSnapshot? snapshot;
  final int byteSize;
}

class StartupSnapshotTooLargeException implements Exception {
  const StartupSnapshotTooLargeException({
    required this.byteSize,
    required this.maxBytes,
  });

  final int byteSize;
  final int maxBytes;

  @override
  String toString() =>
      'Startup snapshot is $byteSize bytes; maximum is $maxBytes bytes';
}

abstract interface class StartupSnapshotStore {
  Future<StartupSnapshotReadResult> read(String userId);
  Future<void> write(StartupSnapshot snapshot);
  Future<void> clear(String userId);
  Future<void> clearAll();
}

typedef CacheDirectoryProvider = Future<Directory> Function();

class JsonStartupSnapshotStore implements StartupSnapshotStore {
  JsonStartupSnapshotStore({
    CacheDirectoryProvider? directoryProvider,
    this.maxBytes = 5 * 1024 * 1024,
  }) : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const String _cacheDirectoryName = 'pinit_startup_cache';

  final CacheDirectoryProvider _directoryProvider;
  final int maxBytes;
  Future<void> _writeQueue = Future<void>.value();

  @override
  Future<StartupSnapshotReadResult> read(String userId) async {
    await _writeQueue;
    final file = await _fileForUser(userId);
    if (!await file.exists()) {
      return const StartupSnapshotReadResult(
        status: StartupSnapshotReadStatus.miss,
      );
    }

    final byteSize = await file.length();
    if (byteSize > maxBytes) {
      return StartupSnapshotReadResult(
        status: StartupSnapshotReadStatus.tooLarge,
        byteSize: byteSize,
      );
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return StartupSnapshotReadResult(
          status: StartupSnapshotReadStatus.corrupt,
          byteSize: byteSize,
        );
      }
      final snapshot = StartupSnapshot.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (snapshot.userId != userId) {
        return StartupSnapshotReadResult(
          status: StartupSnapshotReadStatus.ownershipMismatch,
          byteSize: byteSize,
        );
      }
      return StartupSnapshotReadResult(
        status: StartupSnapshotReadStatus.hit,
        snapshot: snapshot,
        byteSize: byteSize,
      );
    } on StartupSnapshotUnsupportedSchemaException {
      return StartupSnapshotReadResult(
        status: StartupSnapshotReadStatus.unsupportedSchema,
        byteSize: byteSize,
      );
    } catch (_) {
      return StartupSnapshotReadResult(
        status: StartupSnapshotReadStatus.corrupt,
        byteSize: byteSize,
      );
    }
  }

  @override
  Future<void> write(StartupSnapshot snapshot) {
    return _enqueue(() => _writeNow(snapshot));
  }

  @override
  Future<void> clear(String userId) {
    return _enqueue(() async {
      final file = await _fileForUser(userId);
      final temporaryFile = File('${file.path}.tmp');
      if (await file.exists()) await file.delete();
      if (await temporaryFile.exists()) await temporaryFile.delete();
    });
  }

  @override
  Future<void> clearAll() {
    return _enqueue(() async {
      final directory = await _cacheDirectory();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
  }

  @visibleForTesting
  Future<File> debugFileForUser(String userId) => _fileForUser(userId);

  Future<void> _writeNow(StartupSnapshot snapshot) async {
    final encoded = utf8.encode(jsonEncode(snapshot.toJson()));
    if (encoded.length > maxBytes) {
      throw StartupSnapshotTooLargeException(
        byteSize: encoded.length,
        maxBytes: maxBytes,
      );
    }

    final file = await _fileForUser(snapshot.userId);
    await file.parent.create(recursive: true);
    final temporaryFile = File('${file.path}.tmp');

    try {
      await temporaryFile.writeAsBytes(encoded, flush: true);
      try {
        await temporaryFile.rename(file.path);
      } on FileSystemException {
        if (await file.exists()) await file.delete();
        await temporaryFile.rename(file.path);
      }
    } finally {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final queued = _writeQueue.then((_) => operation());
    _writeQueue = queued.catchError((Object _) {});
    return queued;
  }

  Future<Directory> _cacheDirectory() async {
    final root = await _directoryProvider();
    return Directory('${root.path}/$_cacheDirectoryName');
  }

  Future<File> _fileForUser(String userId) async {
    final directory = await _cacheDirectory();
    final hash = sha256.convert(utf8.encode(userId)).toString();
    return File('${directory.path}/$hash.json');
  }
}
