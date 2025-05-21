import 'package:flutter/material.dart';

/// Application spacing and layout constants
class AppSpacing {
  // Basic spacing values
  static const double xs = 4.0;
  static const double small = 8.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  
  // Padding presets
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingSmall = EdgeInsets.all(small);
  static const EdgeInsets paddingMedium = EdgeInsets.all(medium);
  static const EdgeInsets paddingLarge = EdgeInsets.all(large);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);
  
  // Horizontal padding presets
  static const EdgeInsets paddingHorizontalXS = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets paddingHorizontalSmall = EdgeInsets.symmetric(horizontal: small);
  static const EdgeInsets paddingHorizontalMedium = EdgeInsets.symmetric(horizontal: medium);
  static const EdgeInsets paddingHorizontalLarge = EdgeInsets.symmetric(horizontal: large);
  static const EdgeInsets paddingHorizontalXL = EdgeInsets.symmetric(horizontal: xl);
  
  // Vertical padding presets
  static const EdgeInsets paddingVerticalXS = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets paddingVerticalSmall = EdgeInsets.symmetric(vertical: small);
  static const EdgeInsets paddingVerticalMedium = EdgeInsets.symmetric(vertical: medium);
  static const EdgeInsets paddingVerticalLarge = EdgeInsets.symmetric(vertical: large);
  static const EdgeInsets paddingVerticalXL = EdgeInsets.symmetric(vertical: xl);
  
  // Page/screen content padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: medium,
    vertical: medium,
  );
}

/// Application border radius constants
class AppRadius {
  static const double none = 0.0;
  static const double xs = 4.0;
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double circular = 100.0; // For circular shapes
  
  // BorderRadius shortcuts
  static BorderRadius get radiusXS => BorderRadius.circular(xs);
  static BorderRadius get radiusSmall => BorderRadius.circular(small);
  static BorderRadius get radiusMedium => BorderRadius.circular(medium);
  static BorderRadius get radiusLarge => BorderRadius.circular(large);
  static BorderRadius get radiusXL => BorderRadius.circular(xl);
  static BorderRadius get radiusXXL => BorderRadius.circular(xxl);
  static BorderRadius get radiusCircular => BorderRadius.circular(circular);
}

/// Application elevation constants
class AppElevation {
  static const double none = 0.0;
  static const double xs = 1.0;
  static const double small = 2.0;
  static const double medium = 4.0;
  static const double large = 8.0;
  static const double xl = 12.0;
  static const double xxl = 16.0;
}
