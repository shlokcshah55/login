import 'package:flutter/material.dart';

/// Maps a vibe tag (e.g. `coffee_shop`) to its display icon.
const Map<String, IconData> vibeIcons = {
  'cafe': Icons.coffee_rounded,
  'casual': Icons.weekend_rounded,
  'cozy': Icons.fireplace_rounded,
  'coffee_shop': Icons.local_cafe_rounded,
  'bar': Icons.local_bar_rounded,
  'elegant': Icons.diamond_rounded,
  'fine_dining': Icons.restaurant_rounded,
  'food_truck': Icons.local_shipping_rounded,
  'hole_in_the_wall': Icons.door_front_door_rounded,
  'late_night': Icons.nightlife_rounded,
  'live_music': Icons.music_note_rounded,
  'bougie': Icons.star_rounded,
  'modern': Icons.auto_awesome_rounded,
  'fast_food': Icons.fastfood_rounded,
  'quiet': Icons.volume_off_rounded,
  'romantic': Icons.favorite_rounded,
  'sports_bar': Icons.sports_bar_rounded,
  'trendy': Icons.local_fire_department_rounded,
  'takeout_friendly': Icons.takeout_dining_rounded,
  'pub': Icons.sports_bar_rounded,
  'shop': Icons.store_rounded,
  'brunch': Icons.brunch_dining_rounded,
  'outdoor_dining': Icons.deck_rounded,
  'wavy': Icons.waves_rounded,
  'bossman': Icons.storefront_rounded,
};

/// Converts a snake_case vibe tag to a Title Cased display string.
String vibeDisplayName(String tag) {
  return tag
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
