import 'package:flutter/services.dart';

import 'chat_backup_provider.dart';

/// iCloud key-value storage-backed [ChatBackupProvider] — tied to whichever
/// iCloud account the device is already signed into, no separate OAuth
/// consent needed (unlike Android's Google Drive-based provider). Backed
/// by a small native Swift addition wrapping `NSUbiquitousKeyValueStore`
/// (see `ios/Runner/ICloudBackupChannel.swift`) — a tiny key-value blob is
/// exactly what that API is meant for, so no full CloudKit/Drive-style file
/// API is needed here.
///
/// UNVERIFIED: this codebase was built in a Linux-only dev environment with
/// no macOS/Xcode available, so neither this Dart side nor the Swift side
/// has ever been built or run. It also needs the "iCloud → Key-value
/// storage" capability enabled in the Xcode project (an entitlements
/// change) before it can work at all — that step needs a Mac too.
class IosICloudBackupProvider implements ChatBackupProvider {
  static const _channel = MethodChannel('samchat/icloud_backup');

  @override
  bool get isSupported => true;

  @override
  Future<bool> hasBackup() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasBackup');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> upload(String encryptedBlob) async {
    await _channel.invokeMethod('upload', {'blob': encryptedBlob});
  }

  @override
  Future<String?> download() async {
    try {
      return await _channel.invokeMethod<String>('download');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete() async {
    await _channel.invokeMethod('delete');
  }
}
