import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/utils/geo_types.dart';
import 'package:http/http.dart' as http;
import 'dart:developer';

import 'package:login/models/locations.dart';

class GoogleAutocompleteSuggestion {
  final String placeId;
  final String text;
  final String? mainText;
  final String? secondaryText;
  final List<String> types;
  final double? distanceMeters;

  const GoogleAutocompleteSuggestion({
    required this.placeId,
    required this.text,
    this.mainText,
    this.secondaryText,
    this.types = const [],
    this.distanceMeters,
  });
}

class GooglePlacesService {
  final String? apiKey = dotenv.env["GOOGLE_PLACE_API_KEY"];

  // Debug method to check API key
  void debugApiKey() {
    if (apiKey == null) {
      log('GooglePlaceService: API Key loaded: NO');
    } else if (apiKey!.isEmpty) {
      log('GooglePlaceService: API Key loaded: EMPTY STRING');
    } else if (apiKey!.length < 10) {
      log('GooglePlaceService: API Key loaded: YES (${apiKey!.length} chars - TOO SHORT)');
    } else {
      log('GooglePlaceService: API Key loaded: YES (${apiKey!.substring(0, 10)}...)');
    }
    log('GooglePlaceService: All env vars: ${dotenv.env.keys.toList()}');
  }

  // Add method to get photo URL
  String? getPhotoUrl(String? photoReference, {int maxWidth = 400}) {
    if (photoReference == null || photoReference.isEmpty) return null;
    if (apiKey == null || apiKey!.isEmpty) return null;

    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&photoreference=$photoReference&key=$apiKey';
  }

  // Magic search for restaurants based on text query
  Future<List<LocationModel>> searchPlaces({
    required String query,
    double? latitude,
    double? longitude,
    int radius = 2000,
  }) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception(
          'GooglePlaceService: GOOGLE_PLACE_API_KEY not found in .env file');
    }

    String url;
    if (latitude != null && longitude != null) {
      // Location-based search
      url = 'https://maps.googleapis.com/maps/api/place/textsearch/json?'
          'query=${Uri.encodeComponent(query)}&location=$latitude,$longitude&radius=$radius&key=$apiKey';
    } else {
      // General text search
      url = 'https://maps.googleapis.com/maps/api/place/textsearch/json?'
          'query=${Uri.encodeComponent(query)}&key=$apiKey';
    }

    log('GooglePlaceService: Searching with URL: $url');
    return processApiCall(
      url,
      LocationPreference.search,
      includePhotoUrl: false,
    );
  }

  Future<List<LocationModel>> handleMagicSearchQuery(String query) {
    // Enhanced magic search that works better
    return searchPlaces(query: query);
  }

  Future<LocationModel?> fetchPlaceDetails(LocationModel location) async {
    final placeId = location.googlePlaceId?.trim();
    if (placeId == null || placeId.isEmpty) {
      return location;
    }
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception(
        'GooglePlaceService: GOOGLE_PLACE_API_KEY not found in .env file',
      );
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': [
          'place_id',
          'name',
          'formatted_address',
          'geometry',
          'rating',
          'user_ratings_total',
          'price_level',
          'photos',
          'types',
          'formatted_phone_number',
          'international_phone_number',
          'website',
          'business_status',
          'opening_hours',
          'editorial_summary',
          'url',
        ].join(','),
        'key': apiKey!,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      log(
        'GooglePlaceService: Place Details HTTP error '
        '${response.statusCode}: ${response.body}',
      );
      return location;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString();
    if (status != 'OK') {
      log(
        'GooglePlaceService: Place Details API status $status: '
        '${data['error_message'] ?? ''}',
      );
      return location;
    }

    final result = data['result'];
    if (result is! Map<String, dynamic>) {
      return location;
    }

    final detailed = _processPlace(
      result,
      LocationPreference.search,
      includePhotoUrl: true,
    );
    final photosJson = _googlePhotoRefs(result['photos']);
    final openingHours = (result['opening_hours']
            as Map<String, dynamic>?)?['weekday_text'] as List<dynamic>? ??
        const [];

    return detailed.copyWith(
      locationId: location.locationId,
      googlePlaceId: placeId,
      phoneNumber: result['formatted_phone_number']?.toString(),
      internationalPhoneNumber:
          result['international_phone_number']?.toString(),
      website: result['website']?.toString(),
      businessStatus: result['business_status']?.toString(),
      editorialSummary:
          (result['editorial_summary'] as Map<String, dynamic>?)?['overview']
              ?.toString(),
      googleMapsUri: result['url']?.toString(),
      openingHoursText:
          openingHours.map((value) => value.toString()).toList(growable: false),
      photos: photosJson,
      imageUrl: detailed.imageUrl ?? location.imageUrl,
      types: detailed.types ?? location.types,
    );
  }

  Future<List<GoogleAutocompleteSuggestion>> autocompleteFoodAndDrink({
    required String query,
    LatLng? origin,
    int limit = 6,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception(
        'GooglePlaceService: GOOGLE_PLACE_API_KEY not found in .env file',
      );
    }

    final uri = Uri.https('places.googleapis.com', '/v1/places:autocomplete');
    final body = <String, dynamic>{
      'input': trimmed,
      'includeQueryPredictions': false,
      'includedPrimaryTypes': const [
        'restaurant',
        'bar',
        'pub',
        'cafe',
        'night_club',
      ],
    };

    if (origin != null) {
      body['origin'] = {
        'latitude': origin.latitude,
        'longitude': origin.longitude,
      };
      body['locationBias'] = {
        'circle': {
          'center': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'radius': 50000.0,
        },
      };
    }

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey!,
        'X-Goog-FieldMask': 'suggestions.placePrediction.placeId,'
            'suggestions.placePrediction.text.text,'
            'suggestions.placePrediction.structuredFormat.mainText.text,'
            'suggestions.placePrediction.structuredFormat.secondaryText.text,'
            'suggestions.placePrediction.types,'
            'suggestions.placePrediction.distanceMeters',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      log(
        'GooglePlaceService: Autocomplete request failed '
        '(${response.statusCode}): ${response.body}',
      );
      return const [];
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rawSuggestions = decoded['suggestions'] as List<dynamic>? ?? const [];
    final suggestions = rawSuggestions
        .whereType<Map<String, dynamic>>()
        .map(_parseAutocompleteSuggestion)
        .whereType<GoogleAutocompleteSuggestion>()
        .toList();

    suggestions.sort((left, right) {
      final leftDistance = left.distanceMeters ?? double.infinity;
      final rightDistance = right.distanceMeters ?? double.infinity;
      return leftDistance.compareTo(rightDistance);
    });

    return suggestions.take(limit).toList(growable: false);
  }

  Future<List<LocationModel>> fetchNearbyPlaces({
    required double latitude,
    required double longitude,
    required String placeType,
    int radius = 1500,
  }) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception(
          'GooglePlaceService: GOOGLE_PLACE_API_KEY not found in .env file');
    }

    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=$latitude,$longitude&radius=$radius&type=$placeType&key=$apiKey';

    log('GooglePlaceService: Fetching nearby places with URL: $url');
    return processApiCall(url, LocationPreference.recommended);
  }

  GoogleAutocompleteSuggestion? _parseAutocompleteSuggestion(
    Map<String, dynamic> json,
  ) {
    final prediction = json['placePrediction'];
    if (prediction is! Map<String, dynamic>) {
      return null;
    }

    final placeId = prediction['placeId']?.toString();
    final text =
        (prediction['text'] as Map<String, dynamic>?)?['text']?.toString();
    if (placeId == null || placeId.isEmpty || text == null || text.isEmpty) {
      return null;
    }

    final structured =
        prediction['structuredFormat'] as Map<String, dynamic>? ?? const {};
    final types = (prediction['types'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final distanceMeters = prediction['distanceMeters'];

    return GoogleAutocompleteSuggestion(
      placeId: placeId,
      text: text,
      mainText: (structured['mainText'] as Map<String, dynamic>?)?['text']
          ?.toString(),
      secondaryText:
          (structured['secondaryText'] as Map<String, dynamic>?)?['text']
              ?.toString(),
      types: types,
      distanceMeters: distanceMeters is num ? distanceMeters.toDouble() : null,
    );
  }

  Future<List<LocationModel>> processApiCall(
    String url,
    LocationPreference preference, {
    bool includePhotoUrl = true,
  }) async {
    try {
      log('GooglePlaceService: Making API call to: $url');

      final response = await http.get(Uri.parse(url));
      log('GooglePlaceService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log('GooglePlaceService: Response data: ${data.toString().substring(0, 200)}...');

        // Check for API errors
        if (data['status'] != null &&
            data['status'] != 'OK' &&
            data['status'] != 'ZERO_RESULTS') {
          throw Exception(
              'GooglePlaceService: API Error - ${data['status']}: ${data['error_message'] ?? 'Unknown error'}');
        }

        final results = data['results'];
        if (results != null && results.isNotEmpty) {
          List<LocationModel> places = [];
          for (var result in results) {
            try {
              LocationModel place = _processPlace(
                result,
                preference,
                includePhotoUrl: includePhotoUrl,
              );
              places.add(place);
            } catch (e) {
              log('GooglePlaceService: Error processing place: $e');
              // Continue with other places
            }
          }
          log('GooglePlaceService: Successfully processed ${places.length} places');
          return places;
        } else {
          log('GooglePlaceService: No places found in response');
          return []; // Return empty list instead of throwing error
        }
      } else {
        final errorBody = response.body;
        log('GooglePlaceService: HTTP Error ${response.statusCode}: $errorBody');
        throw Exception(
            'GooglePlaceService: HTTP ${response.statusCode} - Failed to fetch places');
      }
    } catch (e) {
      log('GooglePlaceService: Exception during API call: $e');
      rethrow;
    }
  }

  LocationModel _processPlace(
    Map<String, dynamic> result,
    LocationPreference locationPreference, {
    bool includePhotoUrl = true,
  }) {
    try {
      log('GooglePlaceService: Processing place: ${result['name']}');

      var id = result['place_id'];
      var name = result['name'] ?? 'Unknown Place';
      var location = result['geometry']?['location'];

      if (location == null) {
        throw Exception('Place missing location data');
      }

      var lat = location['lat'];
      var lng = location['lng'];
      var vicinity = result['vicinity'] ?? result['formatted_address'] ?? '';
      var rating = result['rating']?.toDouble();
      var userRatingsTotal = result['user_ratings_total'];
      var priceLevel = result['price_level'];

      // Get photo reference safely
      var photoReference;
      if (result['photos'] != null && result['photos'].isNotEmpty) {
        photoReference = result['photos'][0]['photo_reference'];
      }
      // Set imageUrl using getPhotoUrl if photoReference is present
      String? imageUrl;
      if (includePhotoUrl && photoReference != null) {
        imageUrl = getPhotoUrl(photoReference);
      }

      var types = result['types'] as List<dynamic>? ?? [];
      String? cuisine = _extractCuisine(types, name);

      log('GooglePlaceService: Successfully processed place: $name at $lat, $lng');

      final locationId = locationPreference == LocationPreference.search
          ? -id.hashCode.abs()
          : id.hashCode;

      return LocationModel(
        locationId: locationId,
        name: name,
        vicinity: vicinity,
        lat: lat.toDouble(),
        lng: lng.toDouble(),
        createdAt: DateTime.now(),
        cuisine: cuisine,
        rating: rating,
        userRatingsTotal: userRatingsTotal,
        priceLevel: priceLevel,
        photoReference: photoReference,
        imageUrl: imageUrl,
        savedCount: 0,
        googlePlaceId: id?.toString(),
        types: types.map((value) => value.toString()).join(','),
        preference: locationPreference,
      );
    } catch (e) {
      log('GooglePlaceService: Error processing place: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> _googlePhotoRefs(dynamic rawPhotos) {
    if (rawPhotos is! List) return const [];
    return rawPhotos.whereType<Map>().map((photo) {
      final typed = Map<String, dynamic>.from(photo);
      return {
        if (typed['photo_reference'] != null)
          'photo_reference': typed['photo_reference'],
        if (typed['height'] != null) 'height': typed['height'],
        if (typed['width'] != null) 'width': typed['width'],
      };
    }).where((photo) {
      final ref = photo['photo_reference']?.toString();
      return ref != null && ref.isNotEmpty;
    }).toList(growable: false);
  }

  Future<String> getWalkingDuration({
    required LatLng? originLatLng,
    required String destinationPlaceId,
  }) async {
    if (originLatLng == null) {
      return 'N/A';
    }

    if (apiKey == null || apiKey!.isEmpty) {
      log('GooglePlaceService: API key not available for walking duration');
      return 'N/A';
    }

    try {
      log('GooglePlaceService: Getting walking duration from ${originLatLng.latitude}, ${originLatLng.longitude} to $destinationPlaceId');

      double lat = originLatLng.latitude;
      double lng = originLatLng.longitude;

      final String url =
          "https://maps.googleapis.com/maps/api/distancematrix/json?"
          "origins=$lat,$lng"
          "&destinations=place_id:$destinationPlaceId"
          "&mode=walking"
          "&key=$apiKey";

      log('GooglePlaceService: Distance Matrix URL: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        log('GooglePlaceService: Distance Matrix response OK');
        final data = json.decode(response.body);
        log('GooglePlaceService: Distance Matrix data: $data');

        if (data["status"] == "OK" &&
            data["rows"] != null &&
            data["rows"].isNotEmpty &&
            data["rows"][0]["elements"] != null &&
            data["rows"][0]["elements"].isNotEmpty) {
          final element = data["rows"][0]["elements"][0];
          if (element["status"] == "OK" && element["duration"] != null) {
            final duration = element["duration"]["text"];
            log('GooglePlaceService: Walking duration: $duration');
            return _convertDurationToMinutes(duration);
          } else {
            log('GooglePlaceService: Distance Matrix element error: ${element["status"]}');
            return 'N/A';
          }
        } else {
          log('GooglePlaceService: Distance Matrix API error: ${data["status"]}');
          return 'N/A';
        }
      } else {
        log('GooglePlaceService: Distance Matrix HTTP error: ${response.statusCode}');
        return 'N/A';
      }
    } catch (e) {
      log('GooglePlaceService: Exception in getWalkingDuration: $e');
      return 'N/A';
    }
  }

  String _convertDurationToMinutes(String duration) {
    final regex = RegExp(r'(\d+)\s*hours?|\s*(\d+)\s*mins?');
    int totalMinutes = 0;

    for (var match in regex.allMatches(duration)) {
      if (match.group(1) != null) {
        totalMinutes +=
            int.parse(match.group(1)!) * 60; // Convert hours to minutes
      }
      if (match.group(2) != null) {
        totalMinutes += int.parse(match.group(2)!); // Add minutes
      }
    }

    return totalMinutes > 0 ? '${totalMinutes} mins' : duration;
  }

  String? _extractCuisine(List<dynamic> types, String name) {
    const Map<String, String> cuisineFlags = {
      'italian': '🇮🇹', // Italy
      'pizza': '🇮🇹', // Italy
      'pasta': '🇮🇹',
      'sushi': '🇯🇵', // Japan
      'ramen': '🇯🇵', // Japan
      'taco': '🇲🇽', // Mexico
      'mexican': '🇲🇽', // Mexico
      'thai': '🇹🇭', // Thailand
      'indian': '🇮🇳', // India
      'curry': '🇮🇳',
      'piri-piri': '🇵🇹',
      'gyros': '🇬🇷',
      'dosa': '🇮🇳',
      'burger': '🇺🇸', // USA
      'steak': '🇦🇷', // Argentina (famous for steaks)
      'barbecue': '🇺🇸', // USA
      'bbq': '🇺🇸', // USA
      'kebab': '🇹🇷', // Turkey
      'chinese': '🇨🇳', // China
      'cafe': '🇫🇷', // France
      'coffee': '🇮🇹', // Italy (Espresso culture)
      'bakery': '🇫🇷', // France
      'french': '🇫🇷', // France
      'korean': '🇰🇷', // Korea
      'vietnamese': '🇻🇳', // Vietnam
      'seafood': '🇪🇸', // Spain (Paella, seafood culture)
      'middle_eastern': '🇱🇧', // Lebanon
      'turkish': '🇹🇷', // Turkey
      'greek': '🇬🇷', // Greece
      'japanese': '🇯🇵', // Japan
      'spanish': '🇪🇸', // Spain
      'german': '🇩🇪', // Germany
      'brazilian': '🇧🇷', // Brazil
      'argentinian': '🇦🇷', // Argentina
      'portuguese': '🇵🇹', // Portugal
      'lebanese': '🇱🇧', // Lebanon
      'moroccan': '🇲🇦', // Morocco
      'ethiopian': '🇪🇹', // Ethiopia
      'russian': '🇷🇺', // Russia
      'british': '🇬🇧', // United Kingdom
      'american': '🇺🇸', // USA
      'canadian': '🇨🇦', // Canada
      'australian': '🇦🇺', // Australia
      'south_african': '🇿🇦', // South Africa
      'indonesian': '🇮🇩', // Indonesia
      'malaysian': '🇲🇾', // Malaysia
      'filipino': '🇵🇭', // Philippines
      'polish': '🇵🇱', // Poland
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

    return '🌎'; // Default to a neutral flag emoji if no match
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
