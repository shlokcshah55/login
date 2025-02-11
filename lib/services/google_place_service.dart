import 'dart:convert';
import 'dart:ffi';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:developer';

import 'package:login/models/location_model.dart';


class GooglePlacesService {
  final String apiKey = dotenv.env["GOOGLE_PLACE_API_KEY"] ?? 'NOT_SET';

  Future<List<LocationModel>> fetchNearbyPlaces({
    required double latitude,
    required double longitude,
    required String placeType,
    int radius = 1500,
  }) async {
    if (apiKey == 'NOT_SET') {
      throw Exception('GooglePlaceService: API key not set - please add it to your .env file');
    }

    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=$latitude,$longitude&radius=$radius&type=$placeType&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final results = data['results'];
      if (results != null && results.isNotEmpty) {
        List<LocationModel> places = [];
        for (var result in results) {
          LocationModel place = _processPlace(result);
          places.add(place);
        }
        log('GooglePlaceService: Found ${places.length} places');
        return places;
      } else {
        throw Exception('GooglePlaceService: No places found');
      }
    } else {
      throw Exception('GooglePlaceService: Failed to fetch nearby places');
    }
  }

  // LocationModel _processPlace(Map<String, dynamic> result) {
  //   log('GooglePlaceService: Processing place $result');
  //   var id = result['place_id'];
  //   var name = result['name'];
  //   var location = result['geometry']['location'];
  //   var lat = location['lat'];  
  //   var lng = location['lng'];

  //   log('GooglePlaceService: Found place $name at $lat, $lng');

  //   return LocationModel(
  //     id: id,
  //     name: name,
  //     address: '',
  //     description: '',
  //     latitude: lat,
  //     longitude: lng,
  //     preference: LocationPreference.recommended,
  //   );
  // }
  LocationModel _processPlace(Map<String, dynamic> result) {
    log('GooglePlaceService: Processing place $result');
    var id = result['place_id'];
    var name = result['name'];
    var location = result['geometry']['location'];
    var lat = location['lat'];
    var lng = location['lng'];
    var vicinity = result['vicinity'];
    var rating = result['rating']?.toDouble();
    var userRatingsTotal = result['user_ratings_total'];
    var priceLevel = result['price_level'];
    var photoReference = result['photos']?.isNotEmpty == true
        ? result['photos'][0]['photo_reference']
        : null;
    var types = result['types'] as List<dynamic> ? ?? [];
    String? cuisine = _extractCuisine(types, name);

    log('GooglePlaceService: Found place $name at $lat, $lng');

    return LocationModel(
      id: id,
      name: name,
      address: vicinity ?? '',
      description: '',
      latitude: lat,
      longitude: lng,
      cuisine: cuisine,
      preference: LocationPreference.recommended,
      rating: rating,
      userRatingsTotal: userRatingsTotal,
      priceLevel: priceLevel,
      vicinity: vicinity,
      photoReference: photoReference,
      savedCount: 0
    );
  }


Future<String> getWalkingDuration({
  required LatLng? originLatLng,
  required String destinationPlaceId,
}) async {
  if (originLatLng == Null) {
    return '';
  }
  print('got here ok');
  
 



  try {
  print(originLatLng);
  double lat = originLatLng!.latitude;
  double lng = originLatLng!.longitude;
  final String url =
      "https://maps.googleapis.com/maps/api/distancematrix/json?"
      "origins=$lat,$lng"
      "&destinations=place_id:$destinationPlaceId"
      "&mode=walking"
      "&key=$apiKey";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      print('response ok');
      final data = json.decode(response.body);
      print(data);
      if (data["status"] == "OK") {
        final duration = data["rows"][0]["elements"][0]["duration"]["text"];
        return '${_convertDurationToMinutes(duration)} mins';

      } else {
        return '';
      }
    } else {
      print("⚠️ HTTP Error: ${response.statusCode}");
      return 'null';
    }
  } catch (e) {
    print("❌ Exception: $e");
    return 'null';
  }
}

int _convertDurationToMinutes(String duration) {
  final regex = RegExp(r'(\d+)\s*hours?|\s*(\d+)\s*mins?');
  int totalMinutes = 0;

  for (var match in regex.allMatches(duration)) {
    if (match.group(1) != null) {
      totalMinutes += int.parse(match.group(1)!) * 60; // Convert hours to minutes
    }
    if (match.group(2) != null) {
      totalMinutes += int.parse(match.group(2)!); // Add minutes
    }
  }
  
  return totalMinutes;
}


String? _extractCuisine(List<dynamic> types, String name) {
  const Map<String, String> cuisineFlags = {
    'italian': '🇮🇹',  // Italy
    'pizza': '🇮🇹',  // Italy
    'pasta': '🇮🇹',
    'sushi': '🇯🇵',  // Japan
    'ramen': '🇯🇵',  // Japan
    'taco': '🇲🇽',  // Mexico
    'mexican': '🇲🇽',  // Mexico
    'thai': '🇹🇭',  // Thailand
    'indian': '🇮🇳',  // India
    'curry': '🇮🇳',
    'piri-piri': '🇵🇹',
    'gyros':'🇬🇷',
    'dosa':'🇮🇳',
    'burger': '🇺🇸',  // USA
    'steak': '🇦🇷',  // Argentina (famous for steaks)
    'barbecue': '🇺🇸',  // USA
    'bbq': '🇺🇸',  // USA
    'kebab': '🇹🇷',  // Turkey
    'chinese': '🇨🇳',  // China
    'cafe': '🇫🇷',  // France
    'coffee': '🇮🇹',  // Italy (Espresso culture)
    'bakery': '🇫🇷',  // France
    'french': '🇫🇷',  // France
    'korean': '🇰🇷',  // Korea
    'vietnamese': '🇻🇳',  // Vietnam
    'seafood': '🇪🇸',  // Spain (Paella, seafood culture)
    'middle_eastern': '🇱🇧',  // Lebanon
    'turkish': '🇹🇷',  // Turkey
    'greek': '🇬🇷',  // Greece
    'japanese': '🇯🇵',  // Japan
    'spanish': '🇪🇸',  // Spain
    'german': '🇩🇪',  // Germany
    'brazilian': '🇧🇷',  // Brazil
    'argentinian': '🇦🇷',  // Argentina
    'portuguese': '🇵🇹',  // Portugal
    'lebanese': '🇱🇧',  // Lebanon
    'moroccan': '🇲🇦',  // Morocco
    'ethiopian': '🇪🇹',  // Ethiopia
    'russian': '🇷🇺',  // Russia
    'british': '🇬🇧',  // United Kingdom
    'american': '🇺🇸',  // USA
    'canadian': '🇨🇦',  // Canada
    'australian': '🇦🇺',  // Australia
    'south_african': '🇿🇦',  // South Africa
    'indonesian': '🇮🇩',  // Indonesia
    'malaysian': '🇲🇾',  // Malaysia
    'filipino': '🇵🇭',  // Philippines
    'polish': '🇵🇱',  // Poland
  };

  // Check if the place types contain any known cuisines
  for (var type in types) {
    if (cuisineFlags.containsKey(type)) {
      return cuisineFlags[type];
    }
  }

  // Check if the name contains a cuisine-related keyword
  for (var keyword in cuisineFlags.keys) {
    if (name.toLowerCase().contains(keyword)) {
      return cuisineFlags[keyword];
    }
  }

  return '🌎';  // Default to a neutral flag emoji if no match
}



// example response from Google Places API
// {
// "business_status": "OPERATIONAL",
// "geometry":
//   {
//     "location": { "lat": -33.8587323, "lng": 151.2100055 },
//     "viewport":
//       {
//         "northeast":
//           { "lat": -33.85739847010727, "lng": 151.2112436298927 },
//         "southwest":
//           { "lat": -33.86009812989271, "lng": 151.2085439701072 },
//       },
//   },
// "icon": "https://maps.gstatic.com/mapfiles/place_api/icons/v1/png_71/bar-71.png",
// "icon_background_color": "#FF9E67",
// "icon_mask_base_uri": "https://maps.gstatic.com/mapfiles/place_api/icons/v2/bar_pinlet",
// "name": "Cruise Bar",
// "opening_hours": { "open_now": false },
// "photos":
//   [
//     {
//       "height": 608,
//       "html_attributions":
//         [
//           '<a href="https://maps.google.com/maps/contrib/112582655193348962755">A Google User</a>',
//         ],
//       "photo_reference": "Aap_uECvJIZuXT-uLDYm4DPbrV7gXVPeplbTWUgcOJ6rnfc4bUYCEAwPU_AmXGIaj0PDhWPbmrjQC8hhuXRJQjnA1-iREGEn7I0ZneHg5OP1mDT7lYVpa1hUPoz7cn8iCGBN9MynjOPSUe-UooRrFw2XEXOLgRJ-uKr6tGQUp77CWVocpcoG",
//       "width": 1080,
//     },
//   ],
// "place_id": "ChIJi6C1MxquEmsR9-c-3O48ykI",
// "plus_code":
//   {
//     "compound_code": "46R6+G2 The Rocks, New South Wales",
//     "global_code": "4RRH46R6+G2",
//   },
// "price_level": 2,
// "rating": 4,
// "reference": "ChIJi6C1MxquEmsR9-c-3O48ykI",
// "scope": "GOOGLE",
// "types":
//   ["bar", "restaurant", "food", "point_of_interest", "establishment"],
// "user_ratings_total": 1269,
// "vicinity": "Level 1, 2 and 3, Overseas Passenger Terminal, Circular Quay W, The Rocks",
// },
}