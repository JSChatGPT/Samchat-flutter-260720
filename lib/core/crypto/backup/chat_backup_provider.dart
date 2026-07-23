/// Platform-specific storage for the encrypted backup blob (see
/// [ChatBackupCrypto] for what's actually inside it and how it's
/// encrypted). Implementations never see plaintext — they only ever
/// upload/download an opaque already-encrypted string, so this interface
/// carries zero security responsibility itself; it's purely "where does the
/// blob live."
///
/// - Android: [AndroidDriveBackupProvider] — Google Drive `appDataFolder`.
/// - iOS: [IosICloudBackupProvider] — `NSUbiquitousKeyValueStore`.
abstract class ChatBackupProvider {
  /// Whether this platform's cloud storage even applies here (e.g. false on
  /// desktop/web, where there's no equivalent to hook into).
  bool get isSupported;

  /// Whether an encrypted backup blob already exists in the cloud for the
  /// signed-in account — checked before generating a fresh device identity,
  /// so a genuinely new user is never asked "restore?" with nothing to
  /// restore.
  Future<bool> hasBackup();

  /// Uploads (or overwrites) the encrypted blob.
  Future<void> upload(String encryptedBlob);

  /// Downloads the encrypted blob, or null if none exists.
  Future<String?> download();

  /// Deletes the backup — "Turn off backup" in Settings.
  Future<void> delete();
}
