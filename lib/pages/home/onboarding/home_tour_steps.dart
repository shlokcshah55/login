import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/pages/home/home_view_model.dart';
import 'package:login/pages/home/onboarding/tour_hero_widgets.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/widgets/onboarding/spotlight_wizard_overlay.dart';

/// Steps for the first-run home tour, grouped into chapters via the eyebrow:
/// DISCOVER (categories, place card, search), SHARE (TikTok/Instagram),
/// FRIENDS and REWARDS. The optional referral step is appended by the caller.
List<SpotlightWizardStep> buildHomeTourSteps({
  required HomeViewModel viewModel,
  required GlobalKey searchKey,
  required GlobalKey categoryRailKey,
  required GlobalKey focusedStageKey,
  required bool includeShareDemo,
}) {
  Future<void> showRail() async => viewModel.closeCategory();

  Future<void> showFirstCategory() async {
    final categories = viewModel.homeCategories;
    if (categories.isEmpty) return;
    await viewModel.openCategory(categories.first);
  }

  return [
    const SpotlightWizardStep(
      title: 'Welcome to',
      titleLogoAssetPath: 'lib/assets/purplePinit.png',
      illustrationAssetPath:
          'lib/assets/illustrations/Beep Beep - Food Van.svg',
      eyebrow: 'WELCOME',
      description:
          '\nFinding somewhere good to eat should be fun. Here is a 60 second tour of how Pinit works.',
    ),
    SpotlightWizardStep(
      targetKey: categoryRailKey,
      title: 'Start with a vibe.',
      description:
          'Pick a cuisine, a mood, a friend bubble or your own eat-lists. The map and your picks reshape around whatever you tap.',
      eyebrow: 'DISCOVER 1/3',
      placement: SpotlightBubblePlacement.above,
      showHighlightShadow: false,
      badgeIcon: FeatherIcons.compass,
      beforeShow: showRail,
    ),
    SpotlightWizardStep(
      targetKey: focusedStageKey,
      title: 'Swipe the cards.',
      description:
          'Swipe sideways through places and the map follows. Swipe up, or tap a card, for photos, friends who saved it and why it fits you. Tap Save on the card to keep it.',
      eyebrow: 'DISCOVER 2/3',
      placement: SpotlightBubblePlacement.above,
      showHighlightShadow: false,
      badgeIcon: FeatherIcons.layers,
      beforeShow: showFirstCategory,
    ),
    SpotlightWizardStep(
      targetKey: searchKey,
      title: 'Search with magic.',
      description:
          'Type a vibe, a dish or a craving and we will find the best matches. Try Sable’s way for a quick pick.',
      eyebrow: 'DISCOVER 3/3',
      placement: SpotlightBubblePlacement.below,
      highlightShape: SpotlightHighlightShape.pill,
      badgeIcon: FeatherIcons.search,
      beforeShow: showRail,
    ),
    if (includeShareDemo) ...[
      SpotlightWizardStep(
        title: 'See it on TikTok?',
        description: '',
        eyebrow: 'SHARE 1/3',
        badgeIcon: FeatherIcons.share,
        badgeColor: PinitColors.accent,
        bubbleHeightEstimate: 560,
        bodyBuilder: (_) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share any TikTok or Instagram post straight to Pinit.',
              style: _bodyStyle,
            ),
            SizedBox(height: 12),
            TikTokShareDemo(),
          ],
        ),
      ),
      SpotlightWizardStep(
        title: 'We do the digging.',
        description: '',
        eyebrow: 'SHARE 2/3',
        badgeIcon: FeatherIcons.zap,
        bubbleHeightEstimate: 400,
        bodyBuilder: (_) => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pinit reads the post, finds the restaurant and pings you. Confirm the place and it is saved.',
              style: _bodyStyle,
            ),
            SizedBox(height: 14),
            ShareProcessingDemo(),
          ],
        ),
      ),
      SpotlightWizardStep(
        targetKey: categoryRailKey,
        title: 'Saved from your scroll.',
        description:
            'Everything you share lands in this first tile, ready to browse on the map. Share a few videos and watch it fill up.',
        eyebrow: 'SHARE 3/3',
        placement: SpotlightBubblePlacement.above,
        showHighlightShadow: false,
        badgeIcon: FeatherIcons.bookmark,
        beforeShow: showRail,
      ),
    ],
    SpotlightWizardStep(
      title: 'Plan with friends.',
      description: '',
      eyebrow: 'FRIENDS',
      badgeIcon: FeatherIcons.users,
      bubbleHeightEstimate: 420,
      bodyBuilder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Make a bubble with your friends, send places to it and see who has saved what.',
            style: _bodyStyle,
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              height: 170,
              child: Image.asset(
                'lib/assets/wizards/Send-to-bubble.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    ),
    SpotlightWizardStep(
      title: 'Your vouchers.',
      description: '',
      eyebrow: 'REWARDS',
      badgeIcon: FeatherIcons.gift,
      badgeColor: PinitColors.accent,
      bubbleHeightEstimate: 400,
      beforeShow: showRail,
      bodyBuilder: (_) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find vouchers and your referral code on your Profile. Open the menu in the top corner and tap Referrals.',
            style: _bodyStyle,
          ),
          SizedBox(height: 14),
          RewardsPathDemo(),
        ],
      ),
    ),
  ];
}

const TextStyle _bodyStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 14,
  fontWeight: FontWeight.w700,
  color: PinitColors.aubergineSoft,
);
