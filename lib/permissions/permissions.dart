
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestLocationPermission() async {
  PermissionStatus status = await Permission.locationWhenInUse.status;
  if (status.isDenied || status.isRestricted || status.isLimited) {
    status = await Permission.locationWhenInUse.request();
  }
  // Also check for "always" permission if available
  if (!status.isGranted && await Permission.locationAlways.isGranted) {
    status = await Permission.locationAlways.status;
  }
  return status.isGranted;
}
