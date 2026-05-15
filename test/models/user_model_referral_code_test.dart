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
}
