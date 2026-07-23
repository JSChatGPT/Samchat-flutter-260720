import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // See ICloudBackupChannel.swift — unverified, no macOS/Xcode available
    // in the environment this was written in.
    let icloudRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "ICloudBackupChannel")
    ICloudBackupChannel.register(with: icloudRegistrar)
  }
}
