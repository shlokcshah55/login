import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

const String MAPSTYLE = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#ebe3cd"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#523735"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#f5f1e6"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#c9b2a6"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#dcd2be"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#d7d5c6"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#4b6878"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#ae9e90"
      }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#93817c"
      }
    ]
  },
  {
    "featureType": "poi.business",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#a5b076"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#447530"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#f5f1e6"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#fdfcf8"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#f8c967"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#e9bc62"
      }
    ]
  },
  {
    "featureType": "road.highway.controlled_access",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#e98d58"
      }
    ]
  },
  {
    "featureType": "road.highway.controlled_access",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#db8555"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#806b63"
      }
    ]
  },
  {
    "featureType": "transit",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8f7d77"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#ebe3cd"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#dfd2ae"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#b9d3c2"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#92998d"
      }
    ]
  }
]
''';

// Define new colors
const Color primaryTeal = Color(0xFF008080); // Teal
const Color accentCoral = Color(0xFFFF7F50); // Coral
const Color backgroundLinen = Color(0xFFFAF0E6); // Linen (Off-white)
const Color textDarkGrey = Color(0xFF333333); // Dark Grey for text
const Color cardBackground = Colors.white; // White for cards for contrast

final themeData = ThemeData(
  // Use colorScheme for modern theming
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: createMaterialColor(primaryTeal), // Generate swatch from Teal
    accentColor: accentCoral, // Coral as accent
    backgroundColor: backgroundLinen, // Linen background
    cardColor: cardBackground, // White cards
    brightness: Brightness.light, // Assuming a light theme
  ).copyWith(
    secondary: accentCoral, // Explicitly set secondary (used by FAB by default)
    onPrimary: Colors.white, // Text/icon color on primary color
    onSecondary: Colors.white, // Text/icon color on secondary color
    onBackground: textDarkGrey, // Text color on background
    onSurface: textDarkGrey, // Text color on surfaces like cards
  ),

  // Apply Poppins font globally
  textTheme: GoogleFonts.poppinsTextTheme(
    const TextTheme(
      // Define specific styles if needed, otherwise Poppins will be default
      bodyLarge: TextStyle(color: textDarkGrey),
      bodyMedium: TextStyle(color: textDarkGrey),
      titleLarge: TextStyle(color: textDarkGrey, fontWeight: FontWeight.w600), // Slightly bolder titles
      titleMedium: TextStyle(color: textDarkGrey, fontWeight: FontWeight.w600),
      labelLarge: TextStyle(color: Colors.white), // For text on buttons
    ),
  ),

  // Background color
  scaffoldBackgroundColor: backgroundLinen,

  // Button theme using ColorScheme
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryTeal, // Use primary color
      foregroundColor: Colors.white, // Use text color defined in colorScheme.onPrimary
      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600), // Ensure button text is Poppins bold
    ),
  ),

  // Floating action button theme using ColorScheme
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: accentCoral, // Use accent color
    foregroundColor: Colors.white, // Use text color defined in colorScheme.onSecondary
  ),

  // Card theme
  cardTheme: CardTheme(
    color: cardBackground,
    elevation: 4, // Slightly more pronounced shadow
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), // Adjust margin
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Rounded corners
    shadowColor: Colors.grey.withOpacity(0.3), // Softer shadow color
  ),

  // Bottom Navigation Bar Theme
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white, // White background for nav bar
    selectedItemColor: primaryTeal, // Teal for selected icon/label
    unselectedItemColor: Colors.grey[400], // Lighter grey for unselected
    showSelectedLabels: false, // Hide labels if desired
    showUnselectedLabels: false,
    type: BottomNavigationBarType.fixed, // Ensures items don't shift
    elevation: 8, // Add some elevation
  ),

  // AppBar Theme (Optional, if you add AppBars later)
  appBarTheme: AppBarTheme(
    backgroundColor: primaryTeal,
    foregroundColor: Colors.white, // Text/icons on AppBar
    elevation: 0, // Flat AppBar
    titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
  ),

  // Input Decoration Theme (for TextFields)
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withOpacity(0.8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25.0),
      borderSide: BorderSide.none, // No border
    ),
    hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
    contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
  ),
);


// Helper function to create a MaterialColor from a single color
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  strengths.forEach((strength) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  });
  return MaterialColor(color.value, swatch);
}
