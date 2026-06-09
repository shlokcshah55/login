import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:login/models/locations.dart';
import 'package:login/models/proximal_models.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _magicSearchSectionTitleKey = '__magic_search_section_title';

class NaturalLanguageSearchService {
  static const String defaultEndpoint =
      'http://localhost:8080/locations/magic-search';

  final SupabaseService _supabaseService;
  final http.Client _client;
  final String _endpoint;

  NaturalLanguageSearchService({
    SupabaseService? supabaseService,
    http.Client? client,
    String? endpoint,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _client = client ?? http.Client(),
        _endpoint = endpoint ?? resolveMagicSearchEndpoint();

  Future<List<LocationModel>> search({
    required String userId,
    required String query,
    required LatLng currentLocation,
    double radiusKm = 4.0,
    int maxResults = 20,
    bool includeTasteBreakdown = false,
  }) async {
    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
        'prompt': query.trim(),
        'radius_km': radiusKm,
        'max_results': maxResults,
        'include_taste_breakdown': includeTasteBreakdown,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Natural language search failed with ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final recommendationMaps = magicSearchRecommendationMapsFromPayload(
      decoded,
    );
    final fallbackLocations =
        magicSearchRecommendationsToLocationModels(recommendationMaps);
    final locationIds = persistedMagicSearchLocationIds(recommendationMaps);

    if (locationIds.isEmpty) {
      return fallbackLocations;
    }

    final responseRows = await Supabase.instance.client
        .from(SupabaseConstants.tableLocations)
        .select()
        .inFilter(SupabaseConstants.columnLocationId, locationIds);

    final processed =
        await _supabaseService.locations.processLocationsWithImages(
      responseRows as List,
    );
    final byId = <int, LocationModel>{
      for (final location in processed) location.locationId: location,
    };

    return fallbackLocations.map((location) {
      if (location.locationId > 0) {
        final hydrated = byId[location.locationId];
        if (hydrated == null) return location;
        return mergeMagicSearchLocationResult(
          hydrated: hydrated,
          magicSearch: location,
        );
      }
      return location;
    }).toList(growable: false);
  }
}

String resolveMagicSearchEndpoint({Map<String, String>? env}) {
  final source = env ?? _dotenvEnvOrEmpty();
  final override = source['MAGIC_SEARCH_API_URL']?.trim();
  if (override == null || override.isEmpty) {
    return NaturalLanguageSearchService.defaultEndpoint;
  }

  final withoutTrailingSlash = override.replaceFirst(RegExp(r'/+$'), '');
  if (withoutTrailingSlash.endsWith('/locations/magic-search')) {
    return withoutTrailingSlash;
  }
  return '$withoutTrailingSlash/locations/magic-search';
}

Map<String, String> _dotenvEnvOrEmpty() {
  try {
    return dotenv.env;
  } catch (_) {
    return const {};
  }
}

List<int> persistedMagicSearchLocationIds(
  List<Map<String, dynamic>> recommendations,
) {
  final ids = <int>[];
  for (final recommendation in recommendations) {
    final raw = recommendation['location_id'];
    final id = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    if (id != null && id > 0) {
      ids.add(id);
    }
  }
  return ids;
}

List<Map<String, dynamic>> magicSearchRecommendationMapsFromPayload(
  Map<String, dynamic> payload,
) {
  final source = payload['recommendations'] ??
      payload['sections'] ??
      payload['results'] ??
      const [];
  return flattenMagicSearchRecommendations(source);
}

List<Map<String, dynamic>> flattenMagicSearchRecommendations(dynamic source) {
  return _flattenMagicSearchRecommendations(source).toList(growable: false);
}

List<LocationModel> magicSearchRecommendationsToLocationModels(
  List<Map<String, dynamic>> recommendations, {
  Map<String, String>? env,
}) {
  return flattenMagicSearchRecommendations(recommendations)
      .map((recommendation) => _magicSearchRecommendationToLocationModel(
            recommendation,
            env: env,
          ))
      .whereType<LocationModel>()
      .toList(growable: false);
}

LocationModel? _magicSearchRecommendationToLocationModel(
  Map<String, dynamic> json, {
  Map<String, String>? env,
}) {
  final rawId = json['location_id'];
  final locationId =
      rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
  final googlePlaceId = json['google_place_id']?.toString().trim();
  final name = json['name']?.toString().trim();
  if (locationId == null || name == null || name.isEmpty) {
    return null;
  }

  // Magic search returns the same rich Google Places metadata for both
  // known DB rows and external (negative-id) candidates. Plumb every field
  // through so temporary location cards on the home feed render the same
  // way as canonical ones — website, hours, summaries, vibe booleans, etc.
  return LocationModel(
    locationId: locationId,
    name: name,
    vicinity: _optionalString(json['vicinity']) ??
        _optionalString(json['formatted_address']),
    lat: _optionalDouble(json['lat']),
    lng: _optionalDouble(json['lng']),
    createdAt: DateTime.now(),
    googlePlaceId:
        googlePlaceId == null || googlePlaceId.isEmpty ? null : googlePlaceId,
    photoReference: _optionalString(json['photo_reference']),
    imageUrl:
        magicSearchPhotoUrl(_optionalString(json['photo_reference']), env: env),
    rating: _optionalDouble(json['rating']),
    userRatingsTotal: _optionalInt(json['user_ratings_total']),
    priceLevel: _optionalInt(json['price_level']),
    cuisine: _optionalString(json['cuisine_primary']),
    cuisinePrimary: _optionalString(json['cuisine_primary']),
    types: _typesToString(json['types']),
    openNow: _optionalBool(json['open_now']),
    businessStatus: _optionalString(json['business_status']),
    imageStored: _optionalBool(json['image_stored']),
    imageUnavailable: _optionalBool(json['image_unavailable']),
    extraPhotosStored: _optionalInt(json['extra_photos_stored']),
    googleMapsUri: _optionalString(json['google_maps_uri']),
    website: _optionalString(json['website']),
    internationalPhoneNumber:
        _optionalString(json['international_phone_number']),
    editorialSummary: _optionalString(json['editorial_summary']),
    reviewSummary: _optionalString(json['review_summary']),
    openingHoursText: _optionalStringList(json['opening_hours_text']),
    goodForChildren: _optionalBool(json['good_for_children']),
    goodForGroups: _optionalBool(json['good_for_groups']),
    goodForWatchingSports: _optionalBool(json['good_for_watching_sports']),
    liveMusic: _optionalBool(json['live_music']),
    outdoorSeating: _optionalBool(json['outdoor_seating']),
    servesBeer: _optionalBool(json['serves_beer']),
    servesBreakfast: _optionalBool(json['serves_breakfast']),
    servesBrunch: _optionalBool(json['serves_brunch']),
    servesCocktails: _optionalBool(json['serves_cocktails']),
    servesCoffee: _optionalBool(json['serves_coffee']),
    servesDessert: _optionalBool(json['serves_dessert']),
    servesDinner: _optionalBool(json['serves_dinner']),
    servesLunch: _optionalBool(json['serves_lunch']),
    servesVegetarianFood: _optionalBool(json['serves_vegetarian_food']),
    servesWine: _optionalBool(json['serves_wine']),
    matchScore: _optionalDouble(json['final_score']),
    distanceKm: _optionalDouble(json['distance_km']),
    magicSearchRank: _optionalInt(json['rank']),
    magicSearchSources: _optionalStringList(json['source']) ?? const [],
    magicSearchSourceMetadata: _optionalMapList(json['source_metadata']),
    magicSearchMatchReasons:
        _optionalStringList(json['match_reasons']) ?? const [],
    magicSearchIntentMatches: _optionalMap(json['intent_matches']),
    magicSearchConfidence: _optionalDouble(json['confidence']),
    friendSaves: _friendSaves(json['friend_saves']),
    magicSearchSectionTitle: _optionalString(json[_magicSearchSectionTitleKey]),
    preference: LocationPreference.search,
  );
}

LocationModel mergeMagicSearchLocationResult({
  required LocationModel hydrated,
  required LocationModel magicSearch,
}) {
  final hydratedImageUrl = _optionalString(hydrated.imageUrl);
  final hydratedCuisine = _optionalString(hydrated.cuisine);

  return hydrated
      .copyWith(
        vicinity: magicSearch.vicinity,
        lat: magicSearch.lat,
        lng: magicSearch.lng,
        cuisine: hydratedCuisine == null
            ? (magicSearch.cuisine ?? magicSearch.cuisinePrimary)
            : null,
        rating: magicSearch.rating,
        userRatingsTotal: magicSearch.userRatingsTotal,
        priceLevel: magicSearch.priceLevel,
        photoReference: magicSearch.photoReference,
        imageUrl: hydratedImageUrl == null ? magicSearch.imageUrl : null,
        googlePlaceId: magicSearch.googlePlaceId,
        businessStatus: magicSearch.businessStatus,
        editorialSummary: magicSearch.editorialSummary,
        website: magicSearch.website,
        internationalPhoneNumber: magicSearch.internationalPhoneNumber,
        types: magicSearch.types,
        openingHoursText: magicSearch.openingHoursText,
        openNow: magicSearch.openNow,
        cuisinePrimary: magicSearch.cuisinePrimary,
        imageStored: magicSearch.imageStored,
        imageUnavailable: magicSearch.imageUnavailable,
        extraPhotosStored: magicSearch.extraPhotosStored,
        googleMapsUri: magicSearch.googleMapsUri,
        photos: magicSearch.photos,
        reviews: magicSearch.reviews,
        reviewSummary: magicSearch.reviewSummary,
        goodForChildren: magicSearch.goodForChildren,
        goodForGroups: magicSearch.goodForGroups,
        goodForWatchingSports: magicSearch.goodForWatchingSports,
        liveMusic: magicSearch.liveMusic,
        outdoorSeating: magicSearch.outdoorSeating,
        servesBeer: magicSearch.servesBeer,
        servesBreakfast: magicSearch.servesBreakfast,
        servesBrunch: magicSearch.servesBrunch,
        servesCocktails: magicSearch.servesCocktails,
        servesCoffee: magicSearch.servesCoffee,
        servesDessert: magicSearch.servesDessert,
        servesDinner: magicSearch.servesDinner,
        servesLunch: magicSearch.servesLunch,
        servesVegetarianFood: magicSearch.servesVegetarianFood,
        servesWine: magicSearch.servesWine,
        matchScore: magicSearch.matchScore,
        distanceKm: magicSearch.distanceKm,
        magicSearchRank: magicSearch.magicSearchRank,
        magicSearchSources: magicSearch.magicSearchSources.isEmpty
            ? null
            : magicSearch.magicSearchSources,
        magicSearchSourceMetadata: magicSearch.magicSearchSourceMetadata.isEmpty
            ? null
            : magicSearch.magicSearchSourceMetadata,
        magicSearchMatchReasons: magicSearch.magicSearchMatchReasons.isEmpty
            ? null
            : magicSearch.magicSearchMatchReasons,
        magicSearchIntentMatches: magicSearch.magicSearchIntentMatches,
        magicSearchConfidence: magicSearch.magicSearchConfidence,
        friendSaves: magicSearch.friendSaves,
        magicSearchSectionTitle: magicSearch.magicSearchSectionTitle,
      )
      .setPreference(LocationPreference.search);
}

Iterable<Map<String, dynamic>> _flattenMagicSearchRecommendations(
  dynamic source, {
  String? inheritedHeader,
}) sync* {
  if (source is List) {
    for (final item in source) {
      yield* _flattenMagicSearchRecommendations(
        item,
        inheritedHeader: inheritedHeader,
      );
    }
    return;
  }

  if (source is! Map) {
    return;
  }

  final map = Map<String, dynamic>.from(source);
  if (_looksLikeRecommendation(map)) {
    final sectionTitle =
        _optionalString(map[_magicSearchSectionTitleKey]) ?? inheritedHeader;
    if (sectionTitle != null) {
      map[_magicSearchSectionTitleKey] = sectionTitle;
    }
    yield map;
    return;
  }

  final header = _sectionTitle(map) ?? inheritedHeader;
  final childSource = _sectionChildren(map);
  if (childSource != null) {
    yield* _flattenMagicSearchRecommendations(
      childSource,
      inheritedHeader: header,
    );
    return;
  }

  for (final entry in map.entries) {
    final value = entry.value;
    if (value is List || value is Map) {
      yield* _flattenMagicSearchRecommendations(
        value,
        inheritedHeader: _humanizeSectionKey(entry.key) ?? header,
      );
    }
  }
}

bool _looksLikeRecommendation(Map<String, dynamic> map) {
  return map.containsKey('location_id') ||
      map.containsKey('google_place_id') ||
      map.containsKey('place_id');
}

String? _sectionTitle(Map<String, dynamic> map) {
  for (final key in const [
    'header',
    'title',
    'section_title',
    'sectionHeader',
    'label',
  ]) {
    final value = _optionalString(map[key]);
    if (value != null) return value;
  }
  return null;
}

dynamic _sectionChildren(Map<String, dynamic> map) {
  for (final key in const [
    'recommendations',
    'results',
    'items',
    'locations',
    'places',
  ]) {
    final value = map[key];
    if (value is List || value is Map) return value;
  }
  return null;
}

String? _humanizeSectionKey(String key) {
  final cleaned = key
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty || cleaned == 'recommendations') return null;
  return cleaned
      .split(' ')
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

List<FriendSave> _friendSaves(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => FriendSave.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

Map<String, dynamic>? _optionalMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

List<Map<String, dynamic>> _optionalMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String? magicSearchPhotoUrl(String? photoReference,
    {Map<String, String>? env}) {
  final ref = photoReference?.trim();
  if (ref == null || ref.isEmpty) return null;
  if (ref.startsWith('http://') || ref.startsWith('https://')) return ref;

  final apiKey = (env ?? _dotenvEnvOrEmpty())['GOOGLE_PLACE_API_KEY']?.trim();
  if (apiKey == null || apiKey.isEmpty) return null;

  if (ref.startsWith('places/')) {
    return Uri.https(
      'places.googleapis.com',
      '/v1/$ref/media',
      {
        'maxHeightPx': '2000',
        'maxWidthPx': '2000',
        'key': apiKey,
      },
    ).toString();
  }

  return Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/photo',
    {
      'maxwidth': '1600',
      'photoreference': ref,
      'key': apiKey,
    },
  ).toString();
}

String? _optionalString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double? _optionalDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int? _optionalInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

bool? _optionalBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return null;
}

String? _typesToString(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).join(',');
  }
  return _optionalString(value);
}

List<String>? _optionalStringList(dynamic value) {
  if (value is List) {
    final items = <String>[];
    for (final item in value) {
      final text = item?.toString().trim();
      if (text != null && text.isNotEmpty) items.add(text);
    }
    return items.isEmpty ? null : items;
  }
  final single = _optionalString(value);
  return single == null ? null : [single];
}
