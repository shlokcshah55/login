/// The six vibe cards offered in onboarding. Tag ids map to `tags.tag_id`
/// and are written to `users.vibe_tag_affinity` via
/// `tags.updateUserTagsPhotos`.
class VibeOption {
  const VibeOption({
    required this.asset,
    required this.title,
    required this.blurb,
    required this.tagIds,
  });

  final String asset;
  final String title;
  final String blurb;
  final List<String> tagIds;
}

const List<VibeOption> kVibeOptions = [
  VibeOption(
    asset: 'lib/assets/vibe/brunchy.png',
    title: 'Weekend brunchie',
    blurb: 'Lively, social weekend spots',
    tagIds: [
      '5b50e311-533f-450b-b679-bb5009a1430a',
      '80b705b8-c158-4703-b775-b5c00f4fd622',
      '23849d6f-bfb1-4a9a-b02a-11f0357abc75',
      '412190b7-897f-4391-bdfb-205afab14e40',
    ],
  ),
  VibeOption(
    asset: 'lib/assets/vibe/cozy.png',
    title: 'Quiet comfort',
    blurb: 'Warm, cozy and relaxed',
    tagIds: [
      '73a5103f-84e4-4f04-89f7-eff560e44883',
      '0cc10eb4-6935-425e-b177-b528c669b18f',
      '85f83be2-8537-4a9d-94a5-1d5972fc243d',
      'a30e5b03-552a-4134-89d3-cc7bf45c86e0',
    ],
  ),
  VibeOption(
    asset: 'lib/assets/vibe/localSpot.png',
    title: 'No-fuss foodie',
    blurb: 'Casual quick-bite favourites',
    tagIds: [
      'c6d0d291-f782-4890-b703-7a250a53a0a3',
      'e07fea00-c562-46f2-a558-f2ea8d65c030',
      'dea683b2-5730-4a57-bdf5-c8c0e4a7f468',
      '3c3e37d9-9ae0-4201-b998-ceee79bd22e0',
    ],
  ),
  VibeOption(
    asset: 'lib/assets/vibe/rooftop.jpg',
    title: 'Urban socialite',
    blurb: 'Trendy rooftops with views',
    tagIds: [
      '9144608d-669d-4944-ae16-0da81f8ddbb2',
      'c85dbbf9-abba-46e4-a1bc-d30a20ba660a',
      'ddfa5a36-ab39-4dc9-87bd-1c18a39a6b1e',
      '063f8f5b-79bd-4e5a-877e-934689660edb',
    ],
  ),
  VibeOption(
    asset: 'lib/assets/vibe/rusticLocal.png',
    title: 'Rustic local',
    blurb: 'Charming, homey local spots',
    tagIds: [
      '362c3472-c713-45d0-9954-999271c772d6',
      '7f789b3e-ae55-4ac1-83fb-5ba3c785d793',
      '524d0710-f575-457d-8a9e-d00de696140d',
    ],
  ),
  VibeOption(
    asset: 'lib/assets/vibe/upscaleGuy.png',
    title: 'High-end enthusiast',
    blurb: 'Fine dining and upscale venues',
    tagIds: [
      '8960090a-0292-4635-995c-d47366f3b4af',
      '8625848c-d6b5-47ea-8069-e08103ac2d02',
      '4b107468-3693-4878-870d-f907b6924c2b',
      '76b42037-ff12-4536-a7fe-8a6063e95230',
      '878b661e-e245-4fab-95f3-fa5195162828',
      '5d6f988f-68bc-4ac3-bec1-70613f07ed01',
    ],
  ),
];
