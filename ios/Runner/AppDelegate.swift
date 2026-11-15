import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !key.isEmpty {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The phone's hardware ID for sign-in blocking: identifierForVendor, the same for every app from this
    // developer until all of them are removed. Apps can't read the MAC address on iOS.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FFDevice") {
      FlutterMethodChannel(name: "ff/device", binaryMessenger: registrar.messenger()).setMethodCallHandler { call, result in
        if call.method == "hardwareId" {
          result(UIDevice.current.identifierForVendor?.uuidString)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
