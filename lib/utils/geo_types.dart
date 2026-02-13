import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

/// Lightweight coordinate types to decouple the app from any specific map SDK.
/// These replace google_maps_flutter's LatLng and LatLngBounds throughout the
/// codebase so that only the actual map widget/provider files need to know about
/// the Mapbox SDK.

// ─── LatLng ──────────────────────────────────────────────────────────────────

/// A simple latitude / longitude pair.
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  /// Convert to a Mapbox [mapbox.Point].
  mapbox.Point toPoint() => mapbox.Point(
        coordinates: mapbox.Position(longitude, latitude),
      );

  /// Create from a Mapbox [mapbox.Point].
  factory LatLng.fromPoint(mapbox.Point point) => LatLng(
        point.coordinates.lat.toDouble(),
        point.coordinates.lng.toDouble(),
      );

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

// ─── LatLngBounds ────────────────────────────────────────────────────────────

/// Bounding box defined by its southwest and northeast corners.
class LatLngBounds {
  final LatLng southwest;
  final LatLng northeast;

  const LatLngBounds({required this.southwest, required this.northeast});

  /// Convert to a Mapbox [mapbox.CoordinateBounds].
  mapbox.CoordinateBounds toCoordinateBounds() => mapbox.CoordinateBounds(
        southwest: southwest.toPoint(),
        northeast: northeast.toPoint(),
        infiniteBounds: false,
      );

  /// Create from a Mapbox [mapbox.CoordinateBounds].
  factory LatLngBounds.fromCoordinateBounds(
          mapbox.CoordinateBounds bounds) =>
      LatLngBounds(
        southwest: LatLng.fromPoint(bounds.southwest),
        northeast: LatLng.fromPoint(bounds.northeast),
      );
}

// ─── CameraPositionData ──────────────────────────────────────────────────────

/// A plain-data representation of a camera position, independent of the map SDK.
class CameraPositionData {
  final LatLng target;
  final double zoom;
  final double bearing;
  final double tilt;

  const CameraPositionData({
    required this.target,
    this.zoom = 15.0,
    this.bearing = 0.0,
    this.tilt = 0.0,
  });

  /// Convert to Mapbox [mapbox.CameraOptions].
  mapbox.CameraOptions toMapboxCameraOptions() => mapbox.CameraOptions(
        center: target.toPoint(),
        zoom: zoom,
        bearing: bearing,
        pitch: tilt,
      );
}

// ─── MapMarkerData ───────────────────────────────────────────────────────────

/// SDK-independent marker data.  The map widget layer converts these into
/// Mapbox PointAnnotations.
class MapMarkerData {
  final String id;
  final LatLng position;
  final List<int> imageBytes; // PNG image bytes
  final String? title;
  final String? snippet;

  const MapMarkerData({
    required this.id,
    required this.position,
    required this.imageBytes,
    this.title,
    this.snippet,
  });
}
