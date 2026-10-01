import Foundation
import CoreLocation
import Flutter
import UserNotifications

/// Background proximity support: OS region monitoring for saved places,
/// significant-location-change wake-ups to re-pick which places to monitor,
/// and local notifications for when the OS relaunches the app.
///
/// This object is created when `AppDelegate` is, so the location manager's
/// delegate is in place before iOS delivers the events that relaunched the
/// app. Events that arrive before Dart is listening are queued and flushed
/// when Dart calls `ready`.
///
/// It never asks for location permission on its own. Dart requests "Always"
/// at a moment the user can understand (after their first social save).
final class GeofenceManager: NSObject, CLLocationManagerDelegate {
  /// Marks notifications posted here so taps can be told apart from FCM ones.
  static let localNotificationMarker = "pinitLocal"

  /// Ignore a "last known location" older than this when reporting an entry.
  private static let maxLocationAge: TimeInterval = 15 * 60

  private let locationManager = CLLocationManager()
  private var channel: FlutterMethodChannel?
  private var dartReady = false
  private var queuedEvents: [(method: String, arguments: [String: Any])] = []

  override init() {
    super.init()
    locationManager.delegate = self
  }

  func attach(channel: FlutterMethodChannel) {
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result: result)
    }
  }

  // MARK: - Method channel

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "authorizationStatus":
      result(statusString(currentAuthorizationStatus()))

    case "requestAlwaysAuthorization":
      locationManager.requestAlwaysAuthorization()
      result(nil)

    case "registerRegions":
      guard let regions = args["regions"] as? [[String: Any]] else {
        result(FlutterError(code: "INVALID_ARGS", message: "Expected regions", details: nil))
        return
      }
      registerRegions(regions)
      result(nil)

    case "clearRegions":
      stopMonitoringAll()
      result(nil)

    case "setSignificantChangesEnabled":
      setSignificantChanges(enabled: args["enabled"] as? Bool ?? false)
      result(nil)

    case "ready":
      dartReady = true
      flushQueuedEvents()
      result(nil)

    case "postNotification":
      postNotification(args, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Regions

  private func registerRegions(_ regions: [[String: Any]]) {
    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }

    var desired: [String: CLCircularRegion] = [:]
    for region in regions {
      guard let id = region["id"] as? String,
            let lat = region["latitude"] as? Double,
            let lng = region["longitude"] as? Double,
            let radius = region["radius"] as? Double else {
        continue
      }
      let clamped = min(radius, locationManager.maximumRegionMonitoringDistance)
      let circular = CLCircularRegion(
        center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
        radius: clamped,
        identifier: id
      )
      circular.notifyOnEntry = true
      // Exits are not needed: per-place cooldowns prevent repeat nudges, and
      // skipping them avoids extra wake-ups.
      circular.notifyOnExit = false
      desired[id] = circular
    }

    // Keep regions that did not change so iOS does not re-evaluate them.
    var alreadyMonitored = Set<String>()
    for monitored in locationManager.monitoredRegions {
      guard let current = monitored as? CLCircularRegion,
            let wanted = desired[current.identifier],
            sameRegion(current, wanted) else {
        locationManager.stopMonitoring(for: monitored)
        continue
      }
      alreadyMonitored.insert(current.identifier)
    }

    for (id, region) in desired where !alreadyMonitored.contains(id) {
      locationManager.startMonitoring(for: region)
    }
  }

  private func sameRegion(_ a: CLCircularRegion, _ b: CLCircularRegion) -> Bool {
    return abs(a.center.latitude - b.center.latitude) < 1e-6
      && abs(a.center.longitude - b.center.longitude) < 1e-6
      && abs(a.radius - b.radius) < 0.5
  }

  private func stopMonitoringAll() {
    for region in locationManager.monitoredRegions {
      locationManager.stopMonitoring(for: region)
    }
  }

  private func setSignificantChanges(enabled: Bool) {
    guard CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
    if enabled {
      locationManager.startMonitoringSignificantLocationChanges()
    } else {
      locationManager.stopMonitoringSignificantLocationChanges()
    }
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    var args: [String: Any] = ["event": "enter", "identifier": region.identifier]
    if let location = manager.location,
       abs(location.timestamp.timeIntervalSinceNow) < GeofenceManager.maxLocationAge {
      args["latitude"] = location.coordinate.latitude
      args["longitude"] = location.coordinate.longitude
    }
    emit("onGeofenceEvent", args)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    emit("onSignificantLocationChange", [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
    ])
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    emit("onAuthorizationChanged", ["status": statusString(currentAuthorizationStatus())])
  }

  func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
    print("Geofence monitoring failed for region \(region?.identifier ?? "unknown"): \(error)")
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("Geofence location manager error: \(error)")
  }

  private func currentAuthorizationStatus() -> CLAuthorizationStatus {
    if #available(iOS 14.0, *) {
      return locationManager.authorizationStatus
    }
    return CLLocationManager.authorizationStatus()
  }

  private func statusString(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorizedWhenInUse: return "whenInUse"
    case .authorizedAlways: return "always"
    @unknown default: return "notDetermined"
    }
  }

  // MARK: - Local notifications

  private func postNotification(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let id = args["id"] as? String,
          let title = args["title"] as? String,
          let body = args["body"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing id/title/body", details: nil))
      return
    }
    let payload = args["payload"] as? [String: Any] ?? [:]

    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      let allowed: Bool
      switch settings.authorizationStatus {
      case .authorized, .provisional, .ephemeral: allowed = true
      default: allowed = false
      }
      guard allowed else {
        DispatchQueue.main.async { result(false) }
        return
      }

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      content.threadIdentifier = "proximity"
      var userInfo = payload
      userInfo[GeofenceManager.localNotificationMarker] = true
      content.userInfo = userInfo

      let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
      center.add(request) { error in
        DispatchQueue.main.async { result(error == nil) }
      }
    }
  }

  /// Called from `AppDelegate` when a notification posted above is tapped.
  func handleNotificationTap(userInfo: [AnyHashable: Any]) {
    var payload: [String: Any] = [:]
    for (key, value) in userInfo {
      if let key = key as? String, key != GeofenceManager.localNotificationMarker {
        payload[key] = value
      }
    }
    emit("onNotificationTap", ["payload": payload])
  }

  static func isLocalNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
    return (userInfo[localNotificationMarker] as? Bool) == true
  }

  // MARK: - Event delivery

  private func emit(_ method: String, _ arguments: [String: Any]) {
    if dartReady, let channel = channel {
      channel.invokeMethod(method, arguments: arguments)
    } else {
      queuedEvents.append((method: method, arguments: arguments))
    }
  }

  private func flushQueuedEvents() {
    guard let channel = channel else { return }
    let events = queuedEvents
    queuedEvents.removeAll()
    for event in events {
      channel.invokeMethod(event.method, arguments: event.arguments)
    }
  }
}
