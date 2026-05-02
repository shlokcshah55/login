import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "com.example.srishlok.pinit/share"
  private let GEOFENCE_CHANNEL = "com.example.srishlok.pinit/geofence"
  private var shareChannel: FlutterMethodChannel?
  private var geofenceChannel: FlutterMethodChannel?
  private let geofenceManager = GeofenceManager()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Firebase will be initialized by Flutter (main.dart) - don't initialize here to avoid blocking
    // This prevents app launch hang while still supporting push notifications

    // Set up notification delegates (Firebase messaging will be configured from Dart)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    application.registerForRemoteNotifications()

    // Setup method channel for share extension communication
    // Access the root view controller through the FlutterPluginRegistry
    if let controller = window?.rootViewController as? FlutterViewController {
      shareChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)
    }

    shareChannel?.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "saveUserId" {
        self.saveUserId(call: call, result: result)
      } else if call.method == "clearUserId" {
        self.clearUserId(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Setup geofence method channel
    if let controller = window?.rootViewController as? FlutterViewController {
      geofenceChannel = FlutterMethodChannel(name: GEOFENCE_CHANNEL, binaryMessenger: controller.binaryMessenger)
      geofenceManager.setEventChannel(geofenceChannel!)
    }

    geofenceChannel?.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "registerGeofences" {
        guard let regions = call.arguments as? [[String: Any]] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected list of region dicts", details: nil))
          return
        }
        self.geofenceManager.startMonitoring(regions: regions)
        result(nil)
      } else if call.method == "clearGeofences" {
        self.geofenceManager.stopMonitoringAll()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle deep links (for OAuth callbacks)
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    print("📲 AppDelegate: Received deep link: \(url)")

    // Let Flutter handle deep links (Supabase will intercept OAuth callbacks)
    return super.application(app, open: url, options: options)
  }

  // Handle universal links (alternative deep link method)
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  private func saveUserId(call: FlutterMethodCall, result: FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let userId = args["userId"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "Missing userId", details: nil))
      return
    }

    if let userDefaults = UserDefaults(suiteName: "group.com.example.srishlok.pinit") {
      userDefaults.set(userId, forKey: "user_id")
      userDefaults.synchronize()
      print("✅ AppDelegate: Saved user ID to App Group: \(userId)")
      result(nil)
    } else {
      result(FlutterError(code: "UNAVAILABLE", message: "Could not access app group", details: nil))
    }
  }

  private func clearUserId(result: FlutterResult) {
    if let userDefaults = UserDefaults(suiteName: "group.com.example.srishlok.pinit") {
      userDefaults.removeObject(forKey: "user_id")
      userDefaults.synchronize()
      print("🗑️ AppDelegate: Cleared user ID from App Group")
      result(nil)
    } else {
      result(FlutterError(code: "UNAVAILABLE", message: "Could not access app group", details: nil))
    }
  }
}

// MARK: - Firebase Messaging Delegate
// Note: Messaging delegate will be set up from Dart side after Firebase initialization
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("📲 FCM Token received in AppDelegate: \(fcmToken ?? "nil")")

    // Forward token to Flutter via NotificationCenter
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}

// MARK: - Notification Delegates
extension AppDelegate {
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    super.userNotificationCenter(
      center,
      willPresent: notification,
      withCompletionHandler: completionHandler
    )

    // Show notification even when app is in foreground
    // Keep this override minimal so Flutter/Firebase plugins continue to receive
    // the delegate callback chain.
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("📲 Notification tapped: \(userInfo)")

    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("✅ APNs device token received")
    Messaging.messaging().apnsToken = deviceToken
    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }
  
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ Failed to register for remote notifications: \(error)")
    super.application(
      application,
      didFailToRegisterForRemoteNotificationsWithError: error
    )
  }
}
