import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/social_share_presentation_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists presented ids per user', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SocialSharePresentationStore();

    await store.markPresented('user-a', {'notification-1', 'notification-2'});

    expect(
      await SocialSharePresentationStore().presentedIds('user-a'),
      {'notification-1', 'notification-2'},
    );
    expect(await store.presentedIds('user-b'), isEmpty);
  });

  test('keeps newly presented ids when bounded history is full', () async {
    SharedPreferences.setMockInitialValues({
      'social_share_presented_v1_user-a': [
        for (var index = 0; index < 200; index++) 'old-$index',
      ],
    });
    final store = SocialSharePresentationStore();

    await store.markPresented('user-a', {'new-notification'});

    final ids = await store.presentedIds('user-a');
    expect(ids, hasLength(200));
    expect(ids, contains('new-notification'));
  });
}
