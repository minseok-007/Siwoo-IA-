import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Google Maps with API key from Info.plist
    if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
       let dict = NSDictionary(contentsOfFile: path),
       let apiKey = dict["GMSApiKey"] as? String {
      GMSServices.provideAPIKey(apiKey)
    }
    
    // Setup method channel for Google Maps API key
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.example.dogWalkerApp/google_api_key",
      binaryMessenger: controller.binaryMessenger
    )
    
    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getGoogleMapsApiKey" {
        // Try to get from GoogleService-Info.plist first
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let apiKey = dict["API_KEY"] as? String {
          result(apiKey)
        }
        // Fallback to Info.plist GMSApiKey
        else if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
                let dict = NSDictionary(contentsOfFile: path),
                let apiKey = dict["GMSApiKey"] as? String {
          result(apiKey)
        } else {
          result(nil)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
