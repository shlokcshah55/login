import 'package:flutter/widgets.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

// ─────────────────────────────────────────────────────────────
//  Shared vibe tag display config: label + icon.
//  Colours intentionally omitted — pinit palette is cream + aubergine.
//  Used by the location carousel cards and the home category carousel so
//  both surfaces label vibes identically.
// ─────────────────────────────────────────────────────────────
class VibeTagStyle {
  final String label;
  final IconData icon;
  const VibeTagStyle(this.label, this.icon);
}

const Map<String, VibeTagStyle> vibeStyles = {
  'cafe': VibeTagStyle('Café', FeatherIcons.coffee),
  'casual': VibeTagStyle('Casual', FeatherIcons.smile),
  'cozy': VibeTagStyle('Cozy', FeatherIcons.home),
  'coffee_shop': VibeTagStyle('Coffee', FeatherIcons.coffee),
  'bar': VibeTagStyle('Bar', FeatherIcons.moon),
  'elegant': VibeTagStyle('Elegant', FeatherIcons.feather),
  'fine_dining': VibeTagStyle('Fine Dining', FeatherIcons.award),
  'food_truck': VibeTagStyle('Food Truck', FeatherIcons.truck),
  'hole_in_the_wall': VibeTagStyle('Hidden Gem', FeatherIcons.key),
  'late_night': VibeTagStyle('Late Night', FeatherIcons.moon),
  'live_music': VibeTagStyle('Live Music', FeatherIcons.music),
  'bougie': VibeTagStyle('Bougie', FeatherIcons.star),
  'modern': VibeTagStyle('Modern', FeatherIcons.zap),
  'fast_food': VibeTagStyle('Fast Food', FeatherIcons.fastForward),
  'quiet': VibeTagStyle('Quiet', FeatherIcons.volumeX),
  'romantic': VibeTagStyle('Romantic', FeatherIcons.heart),
  'sports_bar': VibeTagStyle('Sports Bar', FeatherIcons.tv),
  'trendy': VibeTagStyle('Trendy', FeatherIcons.trendingUp),
  'takeout_friendly': VibeTagStyle('Takeaway', FeatherIcons.package),
  'pub': VibeTagStyle('Pub', FeatherIcons.home),
  'shop': VibeTagStyle('Shop', FeatherIcons.shoppingCart),
  'brunch': VibeTagStyle('Brunch', FeatherIcons.sun),
  'outdoor_dining': VibeTagStyle('Outdoor', FeatherIcons.wind),
  'wavy': VibeTagStyle('Wavy', FeatherIcons.activity),
  'bossman': VibeTagStyle('Bossman', FeatherIcons.shield),
};
