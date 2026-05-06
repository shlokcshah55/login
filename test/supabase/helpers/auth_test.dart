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

  test(
      'resolveOAuthDisplayName prefers pending Apple full name over metadata and email fallback',
      () {
    final resolvedName = resolveOAuthDisplayName(
      pendingDisplayName: 'Taylor Swift',
      userMetadata: const {
        'name': 'metadata name',
        'full_name': 'metadata full name',
      },
      email: 'taylor.swift@example.com',
    );

    expect(resolvedName, 'Taylor Swift');
  });

  test('resolveOAuthDisplayName falls back to auth metadata before email', () {
    final resolvedName = resolveOAuthDisplayName(
      userMetadata: const {
        'full_name': 'Ada Lovelace',
      },
      email: 'ada@example.com',
    );

    expect(resolvedName, 'Ada Lovelace');
  });

  test('resolveOAuthDisplayName derives a readable fallback from email', () {
    final resolvedName = resolveOAuthDisplayName(
      userMetadata: const {},
      email: 'first.last+foodie@example.com',
    );

    expect(resolvedName, 'first last foodie');
  });
}
