import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;


class GooglePlacesService {
  final String apiKey = dotenv.env["GOOGLE_PLACE_API_KEY"]!;


  Future<List<dynamic>> fetchNearbyPlaces({
    required double latitude,
    required double longitude,
    required String placeType,
    int radius = 1500,
  }) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=$latitude,$longitude&radius=$radius&type=$placeType&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("GooglePlaceService: response for $placeType: $data");
      if (data['status'] == 'OK') {
        return data['results'];
      } else {
        throw Exception('GooglePlaceService: Error from Places API: ${data['status']}');
      }
    } else {
      throw Exception('GooglePlaceService: Failed to fetch nearby places');
    }
  }
}
