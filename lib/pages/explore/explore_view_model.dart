import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/mapbox_search_models.dart';
import 'package:login/services/mapbox_search_service.dart';
import 'package:login/services/recommendations_api.dart';
import 'package:login/supabase/constants.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:supabase_flutter/supabase_flutter.dart';

class ExploreViewModel extends ChangeNotifier {
  final MapboxSearchService _searchService = MapboxSearchService();
  final RecommendationsApi _recommendationsApi = RecommendationsApi();
  final String currentUserId;
  mapbox.MapboxMap? mapController;

  final TextEditingController searchController = TextEditingController();

  // ── Search state ──
  List<MapboxSuggestion> _suggestions = [];
  List<MapboxSuggestion> get suggestions => _suggestions;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  bool _showSuggestions = false;
  bool get showSuggestions => _showSuggestions;

  // ── Results state ──
  List<LocationModel> _locations = [];
  List<LocationModel> get locations => _locations;

  bool _isLoadingResults = false;
  bool get isLoadingResults => _isLoadingResults;

  String? _error;
  String? get error => _error;

  // ── Filter state ──
  final Set<String> _activeVibeTagIds = {};
  Set<String> get activeVibeTagIds => _activeVibeTagIds;

  final Set<String> _activeCuisineTagIds = {};
  Set<String> get activeCuisineTagIds => _activeCuisineTagIds;

  // ── Map state ──
  double? _lastSearchLat;
  double? _lastSearchLng;
  bool _showSearchThisArea = false;
  bool get showSearchThisArea => _showSearchThisArea;

  Timer? _debounce;

  ExploreViewModel({required this.currentUserId, this.mapController}) {
    searchController.addListener(_onSearchChanged);
  }

  // ─────────────────────────────────────────────────────────
  //  Search input handling
  // ─────────────────────────────────────────────────────────

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final query = searchController.text.trim();
    if (query.isEmpty) {
      _suggestions = [];
      _showSuggestions = false;
      notifyListeners();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    _isSearching = true;
    _showSuggestions = true;
    notifyListeners();

    try {
      _suggestions = await _searchService.getSuggestions(query);
    } catch (e) {
      log('ExploreViewModel: Error fetching suggestions: $e');
      _suggestions = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────
  //  Suggestion selection → fly + fetch
  // ─────────────────────────────────────────────────────────

  Future<void> onSuggestionSelected(MapboxSuggestion suggestion) async {
    searchController.removeListener(_onSearchChanged);
    searchController.text = suggestion.name;
    searchController.addListener(_onSearchChanged);

    _showSuggestions = false;
    _isLoadingResults = true;
    notifyListeners();

    try {
      final details =
          await _searchService.retrievePlace(suggestion.mapboxId);
      if (details != null && mapController != null) {
        log('ExploreViewModel: Selected ${details.name} at ${details.latitude}, ${details.longitude}');

        // Pan the map
        await mapController!.flyTo(
          mapbox.CameraOptions(
            center: mapbox.Point(
                coordinates:
                    mapbox.Position(details.longitude, details.latitude)),
            zoom: 14.0,
          ),
          mapbox.MapAnimationOptions(duration: 1000),
        );

        _lastSearchLat = details.latitude;
        _lastSearchLng = details.longitude;
        _showSearchThisArea = false;

        // Fetch recommendations
        await _fetchExploreResults(details.latitude, details.longitude);
      }
    } catch (e) {
      log('ExploreViewModel: Error retrieving place details: $e');
      _error = 'Failed to load area details';
    } finally {
      _isLoadingResults = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────
  //  Core data fetch: Recommendations API → Supabase locations
  // ─────────────────────────────────────────────────────────

  Future<void> _fetchExploreResults(double lat, double lng,
      {double radiusKm = 5.0}) async {
    try {
      final response = await _recommendationsApi.fetchProximal(
        userId: currentUserId,
        latitude: lat,
        longitude: lng,
        radiusKm: radiusKm,
        maxResults: 20,
        tasteWeight: 0.2,
        proximityWeight: 0.6,
        qualityWeight: 0.2,
        vibeTagIds:
            _activeVibeTagIds.isNotEmpty ? _activeVibeTagIds.toList() : null,
        cuisineTagIds: _activeCuisineTagIds.isNotEmpty
            ? _activeCuisineTagIds.toList()
            : null,
      );

      // Extract location IDs preserving rank order
      final locationIds = response.recommendations
          .map((rec) => rec.locationId)
          .where((id) => id > 0)
          .toList();

      if (locationIds.isEmpty) {
        _locations = [];
        _error = 'No restaurants found in this area';
        notifyListeners();
        return;
      }

      // Build a map of locationId → distanceKm/finalScore from the API response
      final Map<int, double> distanceMap = {};
      final Map<int, double> scoreMap = {};
      for (final rec in response.recommendations) {
        if (rec.distanceKm != null) distanceMap[rec.locationId] = rec.distanceKm!;
        if (rec.finalScore != null) scoreMap[rec.locationId] = rec.finalScore!;
      }

      // Fetch full LocationModel objects from Supabase
      _locations = await _fetchLocationsByIds(locationIds);

      // Attach distance/score from API response to each location via matchScore
      _locations = _locations.map((loc) {
        return loc.copyWith(
          matchScore: scoreMap[loc.locationId],
        );
      }).toList();

      _error = null;
      log('ExploreViewModel: Fetched ${_locations.length} locations');
    } catch (e) {
      log('ExploreViewModel: Error fetching results: $e');
      _error = 'Failed to load recommendations';
      _locations = [];
    }
    notifyListeners();
  }

  /// Fetch full LocationModel objects from Supabase by IDs, preserving order.
  /// Mirrors LocationListManager._fetchLocationsByIdsInOrder
  Future<List<LocationModel>> _fetchLocationsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final uniqueIds = ids.toSet().toList();
    final response = await Supabase.instance.client
        .from(SupabaseConstants.tableLocations)
        .select()
        .inFilter(SupabaseConstants.columnLocationId, uniqueIds);

    final Map<int, LocationModel> byId = {};
    for (var item in response as List) {
      final int locationId = item[SupabaseConstants.columnLocationId] as int;
      String? locationImage = item[SupabaseConstants.columnImageUrl];

      // Construct a predictable storage URL if no image_url stored
      if (locationImage == null || locationImage.isEmpty) {
        final filename = '$locationId.jpg';
        locationImage = Supabase.instance.client.storage
            .from('location_photos')
            .getPublicUrl(filename);
      }

      byId[locationId] = LocationModel.fromJson(item, locationImage);
    }

    // Preserve the ranked order from the API
    final List<LocationModel> ordered = [];
    for (final id in ids) {
      final location = byId[id];
      if (location != null) {
        ordered.add(location);
      }
    }
    return ordered;
  }

  // ─────────────────────────────────────────────────────────
  //  Filter chips
  // ─────────────────────────────────────────────────────────

  void toggleVibeFilter(String vibeTagId) {
    if (_activeVibeTagIds.contains(vibeTagId)) {
      _activeVibeTagIds.remove(vibeTagId);
    } else {
      _activeVibeTagIds.add(vibeTagId);
    }
    _refetchIfSearched();
  }

  void toggleCuisineFilter(String cuisineTagId) {
    if (_activeCuisineTagIds.contains(cuisineTagId)) {
      _activeCuisineTagIds.remove(cuisineTagId);
    } else {
      _activeCuisineTagIds.add(cuisineTagId);
    }
    _refetchIfSearched();
  }

  void _refetchIfSearched() {
    if (_lastSearchLat != null && _lastSearchLng != null) {
      _isLoadingResults = true;
      notifyListeners();
      _fetchExploreResults(_lastSearchLat!, _lastSearchLng!);
    } else {
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────
  //  "Search this area" — triggered after user pans the map
  // ─────────────────────────────────────────────────────────

  void onCameraIdle(double lat, double lng) {
    // Only show button if the user has already done an initial search
    // and has panned away from it
    if (_lastSearchLat == null) return;

    final movedEnough = _haversineKm(_lastSearchLat!, _lastSearchLng!, lat, lng) > 0.5;
    if (movedEnough && !_showSearchThisArea) {
      _showSearchThisArea = true;
      notifyListeners();
    }
  }

  Future<void> searchThisArea(double lat, double lng) async {
    _showSearchThisArea = false;
    _isLoadingResults = true;
    _lastSearchLat = lat;
    _lastSearchLng = lng;
    notifyListeners();

    await _fetchExploreResults(lat, lng);
    _isLoadingResults = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────────────────

  void hideSuggestions() {
    _showSuggestions = false;
    _suggestions = [];
    notifyListeners();
  }

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }
}
