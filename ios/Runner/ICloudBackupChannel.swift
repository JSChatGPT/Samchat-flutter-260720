import Flutter
import Foundation

/// Native side of `IosICloudBackupProvider` (see
/// lib/core/crypto/backup/ios_icloud_backup_provider.dart) — wraps
/// `NSUbiquitousKeyValueStore` to store the tiny encrypted device-identity
/// backup blob, synced by iOS across every device signed into the same
/// iCloud account, with no separate OAuth consent needed.
///
/// UNVERIFIED: written in a Linux-only dev environment with no macOS/Xcode
/// available to build or run it. Also needs the "iCloud > Key-value
/// storage" capability added to the Xcode project (an entitlements file
/// change, e.g. Runner.entitlements gaining
/// `com.apple.developer.ubiquity-kvstore-identifier`) before
/// NSUbiquitousKeyValueStore will actually sync anything — that step
/// requires Xcode itself.
class ICloudBackupChannel: NSObject {
  static let channelName = "samchat/icloud_backup"
  private static let backupKey = "samchat_e2ee_backup"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = ICloudBackupChannel()
    channel.setMethodCallHandler(instance.handle)
  }

  private let store = NSUbiquitousKeyValueStore.default

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasBackup":
      result(store.string(forKey: ICloudBackupChannel.backupKey) != nil)
    case "upload":
      guard let args = call.arguments as? [String: Any], let blob = args["blob"] as? String else {
        result(FlutterError(code: "invalid_args", message: "Missing blob argument", details: nil))
        return
      }
      store.set(blob, forKey: ICloudBackupChannel.backupKey)
      store.synchronize()
      result(nil)
    case "download":
      result(store.string(forKey: ICloudBackupChannel.backupKey))
    case "delete":
      store.removeObject(forKey: ICloudBackupChannel.backupKey)
      store.synchronize()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
