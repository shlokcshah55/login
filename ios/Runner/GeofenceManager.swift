import CoreLocation
import Flutter

/// Native CLLocationManager wrapper for region monitoring (geofencing).
/// Supports up to 20 concurrent circular regions (iOS limit).
class GeofenceManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var eventChannel: FlutterMethodChannel?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    /// Set the method channel used to send geofence entry events back to Flutter.
    func setEventChannel(_ channel: FlutterMethodChannel) {
        self.eventChannel = channel
    }

    /// Register circular regions for monitoring.
    /// Each region dict: ["id": Int, "lat": Double, "lng": Double, "radius": Double, "name": String]
    func startMonitoring(regions: [[String: Any]]) {
        // Request Always authorization if we only have WhenInUse
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }

        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("[GeofenceManager] Region monitoring not available")
            return
        }

        // Stop existing monitoring first
        stopMonitoringAll()

        for regionData in regions {
            guard let id = regionData["id"] as? Int,
                  let lat = regionData["lat"] as? Double,
                  let lng = regionData["lng"] as? Double,
                  let radius = regionData["radius"] as? Double,
                  let name = regionData["name"] as? String else {
                continue
            }

            let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            let clampedRadius = min(radius, locationManager.maximumRegionMonitoringDistance)
            let region = CLCircularRegion(center: center, radius: clampedRadius, identifier: "\(id)_\(name)")
            region.notifyOnEntry = true
            region.notifyOnExit = false

            locationManager.startMonitoring(for: region)
        }

        print("[GeofenceManager] Monitoring \(regions.count) regions")
    }

    /// Stop monitoring all regions.
    func stopMonitoringAll() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        print("[GeofenceManager] Stopped monitoring all regions")
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        // Parse locationId from identifier (format: "{id}_{name}")
        let parts = circularRegion.identifier.split(separator: "_", maxSplits: 1)
        guard let idString = parts.first, let locationId = Int(idString) else { return }
        let name = parts.count > 1 ? String(parts[1]) : "a saved place"

        print("[GeofenceManager] Entered region: \(circularRegion.identifier)")

        eventChannel?.invokeMethod("onGeofenceEntry", arguments: [
            "locationId": locationId,
            "name": name,
        ])
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("[GeofenceManager] Monitoring failed for region \(region?.identifier ?? "unknown"): \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("[GeofenceManager] Authorization changed: \(status.rawValue)")
    }
}
