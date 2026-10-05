import 'package:share_plus/share_plus.dart';

/// Shared "invite a friend" message (profile share and onboarding).
class InviteShare {
  InviteShare._();

  static const String appStoreUrl =
      'https://apps.apple.com/gb/app/pinit/id6762100292';

  static String message({String? referralCode, String? bubbleName}) {
    final intro = bubbleName == null
        ? "I've got Pinit and I want to be your friend! 🍽️"
        : "I've started a Pinit bubble called \"$bubbleName\" 🍽️ Come save places with me!";
    final code = (referralCode != null && referralCode.isNotEmpty)
        ? ' Use my referral code $referralCode and we both get rewards!'
        : '';
    return '$intro$code Join me on the app: $appStoreUrl';
  }

  static Future<void> share({String? referralCode, String? bubbleName}) async {
    await Share.share(
      message(referralCode: referralCode, bubbleName: bubbleName),
      subject: 'Join me on Pinit!',
    );
  }
}
