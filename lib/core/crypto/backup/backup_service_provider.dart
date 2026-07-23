import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import '../../storage/local_prefs_service.dart';
import '../e2ee_service.dart';
import 'android_drive_backup_provider.dart';
import 'chat_backup_crypto.dart';
import 'chat_backup_provider.dart';
import 'ios_icloud_backup_provider.dart';

/// Orchestrates the encrypted device-identity backup: picks the right
/// [ChatBackupProvider] for this platform and wires it to
/// [ChatBackupCrypto] and [E2eeService], exposing the small set of
/// operations the Settings screen and the restore-on-login screen need.
/// See lib/core/crypto/backup/chat_backup_crypto.dart for what's actually
/// backed up and why it's enough to recover full chat history.
class ChatBackupService {
  ChatBackupService({required this.e2ee, required this.prefs}) : provider = _providerForPlatform();

  final E2eeService e2ee;
  final LocalPrefsService prefs;
  final ChatBackupProvider? provider;

  static ChatBackupProvider? _providerForPlatform() {
    if (kIsWeb) return null; // no OS-level cloud storage to hook into
    if (Platform.isAndroid) return AndroidDriveBackupProvider();
    if (Platform.isIOS) return IosICloudBackupProvider();
    return null;
  }

  bool get isSupported => provider != null;

  /// Whether a cloud backup exists at all — checked by the restore-on-login
  /// screen before deciding whether to show itself.
  Future<bool> hasCloudBackup() async {
    if (provider == null) return false;
    try {
      return await provider!.hasBackup();
    } catch (_) {
      return false;
    }
  }

  /// Encrypts this device's current identity with [password] and uploads
  /// it — the Settings "Enable backup" / "Change password" flow. Throws on
  /// failure (network/auth error) so the UI can show it; callers should
  /// wrap this in their own try/catch for a user-facing message.
  Future<void> enableBackup(String password) async {
    if (provider == null) throw StateError('Backup isn\'t supported on this platform');
    final identity = await e2ee.exportIdentityForBackup();
    if (identity == null) throw StateError('No local chat identity to back up yet');

    final blob = await ChatBackupCrypto.encrypt(
      password: password,
      deviceId: identity.deviceId,
      privateKeyBase64: identity.privateKeyBase64,
    );
    await provider!.upload(blob);
    await prefs.setChatBackupEnabled(true);
  }

  Future<void> disableBackup() async {
    if (provider != null) {
      try {
        await provider!.delete();
      } catch (_) {
        // Best-effort — still mark it off locally even if the delete call
        // itself failed (e.g. offline). Nothing sensitive is exposed by a
        // stale encrypted blob sitting untouched in the user's own cloud
        // storage; it just stops being kept in sync.
      }
    }
    await prefs.setChatBackupEnabled(false);
  }

  /// Attempts to restore this device's identity from the cloud backup using
  /// [password]. On success, the identity is written to secure storage and
  /// the caller should follow with `E2eeService.ensureDeviceRegistered()`
  /// to register it and pick up every chat's history immediately. Returns
  /// false for a wrong password, no backup found, or any other failure —
  /// the caller should offer a retry or a "skip, start fresh" escape hatch.
  Future<bool> restoreFromBackup(String password) async {
    if (provider == null) return false;
    try {
      final blobJson = await provider!.download();
      if (blobJson == null) return false;
      final identity = await ChatBackupCrypto.decrypt(password: password, blobJson: blobJson);
      if (identity == null) return false; // wrong password or a corrupt blob
      await e2ee.restoreIdentityFromBackup(
        deviceId: identity.deviceId,
        privateKeyBase64: identity.privateKeyBase64,
      );
      await prefs.setChatBackupEnabled(true);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final chatBackupServiceProvider = Provider<ChatBackupService>((ref) {
  return ChatBackupService(
    e2ee: ref.watch(e2eeServiceProvider),
    prefs: ref.watch(localPrefsServiceProvider),
  );
});
