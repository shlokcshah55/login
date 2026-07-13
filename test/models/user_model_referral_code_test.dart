import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/users.dart';
import 'package:login/supabase/constants.dart';

void main() {
  test('parses and serializes referral code', () {
    final user = UserModel.fromJson({
      SupabaseConstants.columnSupabaseId: 'user-1',
      SupabaseConstants.columnEmail: 'test@example.com',
      SupabaseConstants.columnUsername: 'testuser',
      SupabaseConstants.columnReferralCode: 'FRIEND123',
    });

    expect(user.referralCode, 'FRIEND123');
    expect(
      user.toJson()[SupabaseConstants.columnReferralCode],
      'FRIEND123',
    );
  });

  test('copyWith updates referral code', () {
    final user = UserModel(
      supabaseId: 'user-1',
      email: 'test@example.com',
      username: 'testuser',
    );

    expect(user.copyWith(referralCode: 'WELCOME').referralCode, 'WELCOME');
  });

  test('startup fields survive a JSON round trip', () {
    final user = UserModel(
      supabaseId: 'user-1',
      email: 'test@example.com',
      createdAt: DateTime.utc(2026, 1, 2),
      lastLogin: DateTime.utc(2026, 7, 12),
      followersCount: 12,
      followingCount: 8,
      wizardCompleted: true,
      generatedCollections: false,
      verified: true,
    );

    final decoded = UserModel.fromJson(user.toJson());

    expect(decoded.createdAt, user.createdAt);
    expect(decoded.lastLogin, user.lastLogin);
    expect(decoded.followersCount, 12);
    expect(decoded.followingCount, 8);
    expect(decoded.wizardCompleted, isTrue);
    expect(decoded.generatedCollections, isFalse);
    expect(decoded.verified, isTrue);
  });
}
