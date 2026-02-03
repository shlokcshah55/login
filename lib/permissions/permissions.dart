import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Legacy permission function - use LocationService instead for new code.
/// This is kept for backward compatibility.
Future<bool> requestLocationPermission() async {
  // First check if location services are enabled
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print('requestLocationPermission: Location services are disabled');
    return false;
  }

  PermissionStatus status = await Permission.locationWhenInUse.status;
  print('requestLocationPermission: Initial status: $status');
  
  if (status.isDenied || status.isRestricted || status.isLimited) {
    status = await Permission.locationWhenInUse.request();
    print('requestLocationPermission: After request: $status');
  }
  
  // Check if we have "always" permission (which implies "when in use")
  if (!status.isGranted) {
    final alwaysStatus = await Permission.locationAlways.status;
    if (alwaysStatus.isGranted) {
      print('requestLocationPermission: Has locationAlways permission');
      return true;
    }
  }
  
  return status.isGranted || status.isLimited;
}

/// Check if location permission is permanently denied
Future<bool> isLocationPermissionPermanentlyDenied() async {
  final status = await Permission.locationWhenInUse.status;
  return status.isPermanentlyDenied;
}

/// Open app settings so user can enable location permission
Future<bool> openLocationAppSettings() async {
  return await openAppSettings();
}

/// Open device location settings so user can enable GPS
Future<bool> openDeviceLocationSettings() async {
  return await Geolocator.openLocationSettings();
}
