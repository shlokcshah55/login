import 'package:flutter_test/flutter_test.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/helpers/auth.dart';

void main() {
  test('resolveMutualFriendIds keeps only users present in both directions',
      () {
    final mutualIds = resolveMutualFriendIds(
      followingRows: const [
        {
          SupabaseConstants.columnFolloweeId: 'mutual-user',
        },
        {
          SupabaseConstants.columnFolloweeId: 'outbound-only-user',
        },
      ],
      followerRows: const [
        {
          SupabaseConstants.columnFollowerId: 'mutual-user',
        },
        {
          SupabaseConstants.columnFollowerId: 'inbound-only-user',
        },
      ],
    );

    expect(mutualIds, {'mutual-user'});
  });
}
