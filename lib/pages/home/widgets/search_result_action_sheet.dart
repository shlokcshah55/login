import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/services/recommendations_api.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/widgets/home/expanded_card/add_to_bubble_sheet.dart';
import 'package:login/widgets/home/expanded_card/add_to_collection_sheet.dart';
import 'package:provider/provider.dart';

class SearchResultActionHandler {
  SearchResultActionHandler._();

  static final RecommendationsApi _recommendationsApi = RecommendationsApi();
  static const List<Duration> _hydrationRetryDelays = [
    Duration.zero,
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(milliseconds: 900),
  ];

  static Future<LocationModel?> ensureLocationReady(
      LocationModel location) async {
    if (location.locationId > 0) {
      return await _fetchLocationById(location.locationId) ?? location;
    }

    final googlePlaceId = location.googlePlaceId?.trim();
    if (googlePlaceId == null || googlePlaceId.isEmpty) {
      return location;
    }

    final locationId = await _recommendationsApi.addLocationByGooglePlaceId(
      googlePlaceId: googlePlaceId,
      source: 'in-app',
    );
    if (locationId == null) {
      return null;
    }

    final hydrated = await _fetchLocationById(locationId);
    if (hydrated != null) {
      return hydrated;
    }

    return location.copyWith(locationId: locationId);
  }

  static Future<void> save(
    BuildContext context,
    LocationModel location,
  ) async {
    final hydrated = await ensureLocationReady(location);
    if (hydrated == null) {
      return;
    }
    await context.read<LocationListManager>().saveLocation(hydrated);
  }

  static Future<int?> sendToBubble(
    BuildContext context,
    LocationModel location,
  ) async {
    final hydrated = await ensureLocationReady(location);
    if (hydrated == null) {
      return null;
    }
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToBubbleSheet(location: hydrated),
    );
  }

  static Future<void> addToCollection(
    BuildContext context,
    LocationModel location,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToCollectionSheet(
        locationId: location.locationId,
        locationName: location.name,
      ),
    );
  }

  static Future<LocationModel?> _fetchLocationById(int locationId) async {
    if (locationId <= 0) {
      return null;
    }

    for (final delay in _hydrationRetryDelays) {
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      try {
        final rows = (await SupabaseClientManager()
            .client
            .from(SupabaseConstants.tableLocations)
            .select()
            .eq(SupabaseConstants.columnLocationId, locationId)
            .limit(1)) as List;

        if (rows.isEmpty) {
          continue;
        }

        final processed =
            await SupabaseService().locations.processLocationsWithImages(
                  rows,
                );
        if (processed.isNotEmpty) {
          return processed.first;
        }

        final raw = rows.first;
        if (raw is Map<String, dynamic>) {
          return LocationModel.fromJson(raw, null);
        }
        if (raw is Map) {
          return LocationModel.fromJson(
            raw.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
            null,
          );
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }
}
