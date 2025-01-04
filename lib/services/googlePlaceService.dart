import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;


class GooglePlacesService {
  final String apiKey = dotenv.env["GOOGLE_PLACE_API_KEY"] ?? 'NOT_SET';

  Future<List<dynamic>> fetchNearbyPlaces({
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
        var places = [];
        for (var result in results) {
          Map<String, dynamic> place = _processPlace(result);
          places.add(place);
        }
        print('GooglePlaceService: Found ${places.length} places');
        return places;
      } else {
        throw Exception('GooglePlaceService: Error from Places API: ${data['status']}');
      }
    } else {
      throw Exception('GooglePlaceService: Failed to fetch nearby places');
    }
  }

  Map<String, dynamic> _processPlace(Map<String, dynamic> result) {
    var name = result['name'];
    var location = result['geometry']['location'];
    var lat = location['lat'];
    var lng = location['lng'];
    print('GooglePlaceService: Found place $name at $lat, $lng');
    return {'name': name, 'lat': lat, 'lng': lng};
  }
}
