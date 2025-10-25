import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "com.example.srishlok.pinit/share"
  private var shareChannel: FlutterMethodChannel?

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
    shareChannel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)

    shareChannel?.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
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

  // Handle deep links (for OAuth callbacks and share extension)
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    print("📲 AppDelegate: Received deep link: \(url)")

    // Handle share extension deep link
    if url.scheme == "pinit" && url.host == "share" {
      print("📲 AppDelegate: Detected share extension deep link")

      // Notify Flutter to check for shared URLs
      // Small delay to ensure Flutter is ready
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
        print("📲 AppDelegate: Notifying Flutter about shared data")
        self?.shareChannel?.invokeMethod("onSharedData", arguments: nil)
      }

      return true
    }

    // Let Flutter handle other deep links (Supabase will intercept OAuth callbacks)
    return super.application(app, open: url, options: options)
  }

  // Handle universal links (alternative deep link method)
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  private func getSharedURLs(result: FlutterResult) {
    if let userDefaults = UserDefaults(suiteName: "group.com.example.srishlok.pinit") {
      let urls = userDefaults.stringArray(forKey: "shared_url") ?? []
      result(urls)
    } else {
      result(FlutterError(code: "UNAVAILABLE", message: "Could not access app group", details: nil))
    }
  }

  private func clearSharedURLs(result: FlutterResult) {
    if let userDefaults = UserDefaults(suiteName: "group.com.example.srishlok.pinit") {
      userDefaults.removeObject(forKey: "shared_url")
      userDefaults.synchronize()
      result(nil)
    } else {
      result(FlutterError(code: "UNAVAILABLE", message: "Could not access app group", details: nil))
    }
  }
}
