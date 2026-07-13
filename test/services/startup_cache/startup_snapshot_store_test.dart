import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/users.dart';
import 'package:login/services/startup_cache/startup_snapshot.dart';
import 'package:login/services/startup_cache/startup_snapshot_store.dart';

void main() {
  late Directory directory;
  late JsonStartupSnapshotStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pinit-startup-cache-');
    store = JsonStartupSnapshotStore(
      directoryProvider: () async => directory,
      maxBytes: 1024 * 1024,
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('writes and reads the matching user snapshot', () async {
    await store.write(_snapshot(userId: 'user-1', name: 'First'));

    final result = await store.read('user-1');

    expect(result.status, StartupSnapshotReadStatus.hit);
    expect(result.snapshot?.profile?.name, 'First');
    expect(result.byteSize, greaterThan(0));
    expect((await store.read('user-2')).status, StartupSnapshotReadStatus.miss);
  });

  test('filenames do not expose the user id', () async {
    final file = await store.debugFileForUser('private-user-id');

    expect(file.path, isNot(contains('private-user-id')));
    expect(file.path, endsWith('.json'));
  });

  test('corrupt JSON returns a corrupt result', () async {
    await store.write(_snapshot(userId: 'user-1'));
    final file = await store.debugFileForUser('user-1');
    await file.writeAsString('{broken');

    expect(
      (await store.read('user-1')).status,
      StartupSnapshotReadStatus.corrupt,
    );
  });

  test('unsupported schema returns an unsupported result', () async {
    await store.write(_snapshot(userId: 'user-1'));
    final file = await store.debugFileForUser('user-1');
    final json = _snapshot(userId: 'user-1').toJson()..['schema_version'] = 999;
    await file.writeAsString(jsonEncode(json));

    expect(
      (await store.read('user-1')).status,
      StartupSnapshotReadStatus.unsupportedSchema,
    );
  });

  test('snapshot ownership mismatch is rejected', () async {
    await store.write(_snapshot(userId: 'user-1'));
    final file = await store.debugFileForUser('user-1');
    await file.writeAsString(jsonEncode(_snapshot(userId: 'user-2').toJson()));

    expect(
      (await store.read('user-1')).status,
      StartupSnapshotReadStatus.ownershipMismatch,
    );
  });

  test('oversized files are rejected before decoding', () async {
    final smallStore = JsonStartupSnapshotStore(
      directoryProvider: () async => directory,
      maxBytes: 10,
    );
    final file = await smallStore.debugFileForUser('user-1');
    await file.parent.create(recursive: true);
    await file.writeAsString('x' * 11);

    expect(
      (await smallStore.read('user-1')).status,
      StartupSnapshotReadStatus.tooLarge,
    );
  });

  test('oversized snapshots are not written', () async {
    final smallStore = JsonStartupSnapshotStore(
      directoryProvider: () async => directory,
      maxBytes: 10,
    );

    await expectLater(
      smallStore.write(_snapshot(userId: 'user-1')),
      throwsA(isA<StartupSnapshotTooLargeException>()),
    );
  });

  test('replacement leaves the latest complete snapshot and no temp file',
      () async {
    await store.write(_snapshot(userId: 'user-1', name: 'First'));
    await store.write(_snapshot(userId: 'user-1', name: 'Second'));

    final file = await store.debugFileForUser('user-1');
    expect((await store.read('user-1')).snapshot?.profile?.name, 'Second');
    expect(await File('${file.path}.tmp').exists(), isFalse);
  });

  test('clear removes one user without removing another', () async {
    await store.write(_snapshot(userId: 'user-1'));
    await store.write(_snapshot(userId: 'user-2'));

    await store.clear('user-1');

    expect((await store.read('user-1')).status, StartupSnapshotReadStatus.miss);
    expect((await store.read('user-2')).status, StartupSnapshotReadStatus.hit);
  });

  test('clearAll removes only the startup cache directory', () async {
    final unrelated = File('${directory.path}/keep.txt');
    await unrelated.writeAsString('keep');
    await store.write(_snapshot(userId: 'user-1'));

    await store.clearAll();

    expect((await store.read('user-1')).status, StartupSnapshotReadStatus.miss);
    expect(await unrelated.exists(), isTrue);
  });
}

StartupSnapshot _snapshot({
  required String userId,
  String name = 'Cached User',
}) {
  return StartupSnapshot(
    schemaVersion: StartupSnapshot.currentSchemaVersion,
    userId: userId,
    writtenAt: DateTime.utc(2026, 7, 13),
    profile: UserModel(
      supabaseId: userId,
      email: '$userId@example.com',
      name: name,
    ),
    savedLocations: const [],
    acceptedConsentVersion: 'v1',
  );
}
