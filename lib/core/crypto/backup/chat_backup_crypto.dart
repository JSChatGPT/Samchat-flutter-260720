import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../e2ee_primitives.dart';

/// This device's identity, as recovered from (or about to be written to) an
/// encrypted backup — see [ChatBackupCrypto].
class RecoveredIdentity {
  const RecoveredIdentity({required this.deviceId, required this.privateKeyBase64});

  final String deviceId;
  final String privateKeyBase64;
}

/// Encrypts/decrypts the small device-identity blob backed up to the user's
/// own cloud storage (Google Drive appDataFolder / iCloud key-value store —
/// see the platform ChatBackupProvider implementations). Reuses
/// [E2eePrimitives]' ChaCha20-Poly1305 AEAD for the actual encryption; the
/// only new primitive here is deriving a symmetric key from a user-chosen
/// password via Argon2id, since (unlike a chat key) nothing generates this
/// key for us — it has to be something only the user knows, or this
/// wouldn't be an end-to-end-encrypted backup, just a regular one.
///
/// What gets backed up is deliberately tiny: this device's identity
/// (device_id + X25519 private key), not message history. The server
/// already permanently stores every message as ciphertext, and every
/// existing `chat_key_grants` row sealed to this identity's public key is
/// still sitting there — restoring the identity is enough to make every
/// chat's entire history readable again immediately, with no separate
/// per-message or per-chat backup step.
class ChatBackupCrypto {
  ChatBackupCrypto._();

  // OWASP mobile-appropriate Argon2id parameters — deliberately lighter
  // than server-side recommendations, since this has to run on-device
  // (including older/low-end phones) without a noticeable UI stall.
  static final _argon2id = Argon2id(parallelism: 1, memory: 19456, iterations: 2, hashLength: 32);

  static const _saltLength = 16;
  static const _formatVersion = 1;

  /// Encrypts this device's identity with a key derived from [password].
  /// Output is a small JSON blob safe to upload as-is — nothing in it is
  /// readable without the password. The salt itself isn't secret, it's only
  /// there so the same password doesn't derive the same key on a different
  /// backup.
  static Future<String> encrypt({
    required String password,
    required String deviceId,
    required String privateKeyBase64,
  }) async {
    final salt = _randomBytes(_saltLength);
    final key = await _deriveKey(password, salt);
    final payload = jsonEncode({'device_id': deviceId, 'private_key': privateKeyBase64});
    final ciphertext = await E2eePrimitives.encryptMessage(plainText: payload, chatKey: key);
    return jsonEncode({'v': _formatVersion, 'salt': base64Encode(salt), 'ciphertext': ciphertext});
  }

  /// Reverses [encrypt]. Returns null on a wrong password (AEAD
  /// authentication failure) or a malformed/corrupt blob — never throws, so
  /// callers can treat "wrong password" and "no usable backup" uniformly.
  static Future<RecoveredIdentity?> decrypt({required String password, required String blobJson}) async {
    try {
      final blob = jsonDecode(blobJson) as Map<String, dynamic>;
      final salt = base64Decode(blob['salt'] as String);
      final key = await _deriveKey(password, salt);
      final decrypted = await E2eePrimitives.decryptMessage(
        cipherTextBase64: blob['ciphertext'] as String,
        chatKey: key,
      );
      final payload = jsonDecode(decrypted) as Map<String, dynamic>;
      return RecoveredIdentity(
        deviceId: payload['device_id'] as String,
        privateKeyBase64: payload['private_key'] as String,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<SecretKey> _deriveKey(String password, List<int> salt) {
    return _argon2id.deriveKeyFromPassword(password: password, nonce: salt);
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }
}
