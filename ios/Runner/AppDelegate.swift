import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "com.example.srishlok.pinit/share"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Load Google Maps API key from Info.plist for security
    if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
       let plist = NSDictionary(contentsOfFile: path),
       let apiKey = plist["GOOGLE_MAPS_API_KEY"] as? String {
      GMSServices.provideAPIKey(apiKey)
    }

    // Setup method channel for share extension communication
    let controller = window?.rootViewController as! FlutterViewController
    let shareChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)

    shareChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getSharedURLs" {
        self.getSharedURLs(result: result)
      } else if call.method == "clearSharedURLs" {
        self.clearSharedURLs(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle deep links (for OAuth callbacks)
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Let Flutter handle the deep link (Supabase will intercept OAuth callbacks)
    return super.application(app, open: url, options: options)
  }

  // Handle universal links (alternative deep link method)
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  private func getSharedURLs(result: FlutterResult) {
    if let userDefaults = UserDefaults(suiteName: "group.pinit.app") {
      let urls = userDefaults.stringArray(forKey: "shared_url") ?? []
      result(urls)
    } else {
      result(FlutterError(code: "UNAVAILABLE", message: "Could not access app group", details: nil))
    }
  }

  private func clearSharedURLs(result: FlutterResult) {
    if let userDefaults = UserDefaults(suiteName: "group.pinit.app") {
      userDefaults.removeObject(forKey: "shared_url")
      userDefaults.synchronize()
      result(nil)
    } else {
      result(FlutterError(code: "UNAVAILABLE", message: "Could not access app group", details: nil))
    }
  }
}
