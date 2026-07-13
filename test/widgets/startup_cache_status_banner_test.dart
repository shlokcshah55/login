import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/users.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/services/startup_cache/startup_cache_coordinator.dart';
import 'package:login/services/startup_cache/startup_snapshot.dart';
import 'package:login/services/startup_cache/startup_snapshot_store.dart';
import 'package:login/widgets/startup_cache_status_banner.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput: 'GOOGLE_PLACE_API_KEY=test\nAPI_SECRET_KEY=test\n',
    );
  });

  testWidgets('keeps content visible without a banner while data is usable',
      (tester) async {
    final coordinator = StartupCacheCoordinator(store: _FakeStore());
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: coordinator,
        child: const MaterialApp(
          home: StartupCacheStatusBanner(
            child: Text('Home content'),
          ),
        ),
      ),
    );

    expect(find.text('Home content'), findsOneWidget);
    expect(find.text('Showing saved data'), findsNothing);

    coordinator.markRefreshStarted();
    await tester.pump();
    expect(find.text('Home content'), findsOneWidget);
    expect(find.text('Showing saved data'), findsNothing);

    coordinator.markRefreshCompleted(hadFailure: false);
    await tester.pump();
    expect(find.text('Showing saved data'), findsNothing);
  });

  testWidgets('shows a non-blocking banner when cached refresh fails',
      (tester) async {
    final coordinator = StartupCacheCoordinator(
      store: _FakeStore(
        result: StartupSnapshotReadResult(
          status: StartupSnapshotReadStatus.hit,
          snapshot: StartupSnapshot(
            schemaVersion: StartupSnapshot.currentSchemaVersion,
            userId: 'user-1',
            writtenAt: DateTime.utc(2026, 7, 13),
            profile: UserModel(
              supabaseId: 'user-1',
              email: 'cached@example.com',
            ),
            savedLocations: const [],
            acceptedConsentVersion: 'v1',
          ),
        ),
      ),
    );
    addTearDown(coordinator.dispose);
    await coordinator.hydrate(
      userId: 'user-1',
      userDataProvider: UserDataProvider(),
      locationListManager: LocationListManager(
        GooglePlacesService(),
        startBackgroundUserServices: false,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: coordinator,
        child: const MaterialApp(
          home: StartupCacheStatusBanner(
            child: Text('Home content'),
          ),
        ),
      ),
    );

    coordinator.markRefreshStarted();
    coordinator.markRefreshCompleted(hadFailure: true);
    await tester.pump();

    expect(find.text('Home content'), findsOneWidget);
    expect(find.text('Showing saved data'), findsOneWidget);
  });
}

class _FakeStore implements StartupSnapshotStore {
  _FakeStore({
    this.result = const StartupSnapshotReadResult(
      status: StartupSnapshotReadStatus.miss,
    ),
  });

  final StartupSnapshotReadResult result;

  @override
  Future<void> clear(String userId) async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<StartupSnapshotReadResult> read(String userId) async {
    return result;
  }

  @override
  Future<void> write(StartupSnapshot snapshot) async {}
}
