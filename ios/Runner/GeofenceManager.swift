import Foundation
import CoreLocation
import Flutter

class GeofenceManager: NSObject, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private var eventChannel: FlutterMethodChannel?

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.requestAlwaysAuthorization()
  }

  func setEventChannel(_ channel: FlutterMethodChannel) {
    self.eventChannel = channel
  }

  func startMonitoring(regions: [[String: Any]]) {
    stopMonitoringAll()

    for region in regions {
      guard let id = region["id"] as? String,
            let lat = region["latitude"] as? Double,
            let lng = region["longitude"] as? Double,
            let radius = region["radius"] as? Double else {
        continue
      }

      let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
      let clampedRadius = min(radius, locationManager.maximumRegionMonitoringDistance)
      let circularRegion = CLCircularRegion(center: center, radius: clampedRadius, identifier: id)
      circularRegion.notifyOnEntry = true
      circularRegion.notifyOnExit = true
      locationManager.startMonitoring(for: circularRegion)
    }
  }

  func stopMonitoringAll() {
    for region in locationManager.monitoredRegions {
      locationManager.stopMonitoring(for: region)
    }
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    eventChannel?.invokeMethod("onGeofenceEvent", arguments: [
      "event": "enter",
      "identifier": region.identifier
    ])
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    eventChannel?.invokeMethod("onGeofenceEvent", arguments: [
      "event": "exit",
      "identifier": region.identifier
    ])
  }

  func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    print("Geofence monitoring failed for region \(region?.identifier ?? "unknown"): \(error)")
  }
}
