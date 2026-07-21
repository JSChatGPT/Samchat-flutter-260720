import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Low-level E2EE building blocks — no I/O, no storage, just bytes in/out.
///
/// Deliberately built from standardized, independently-audited primitives
/// (X25519 key exchange per RFC 7748, BLAKE2b hashing, ChaCha20-Poly1305 AEAD
/// per RFC 7539) rather than a library-specific "sealed box" helper, because
/// this exact protocol has to be reimplemented byte-for-byte in JavaScript
/// (via libsodium-wrappers, see resources/js/crypto.js on the backend) for
/// the web client — matching an official RFC is a much safer bet for
/// cross-language interop than trying to replicate an undocumented,
/// implementation-specific internal construction.
///
/// Known limitations of this v1 protocol (see the plan doc for the full
/// rationale): no forward secrecy, no automatic re-keying on membership
/// change, multi-device = independent keypairs per device.
class E2eePrimitives {
  E2eePrimitives._();

  static final _x25519 = X25519();
  static final _cipher = Chacha20.poly1305Aead();
  // Explicit 32-byte output — BLAKE2b defaults to 64 bytes, which doesn't
  // fit the 32-byte key ChaCha20-Poly1305 expects. The web side's
  // libsodium.js crypto_generichash() call must also request exactly 32
  // bytes to match.
  static final _hash = Blake2b(hashLengthInBytes: 32);

  /// A fresh X25519 device keypair, generated once per app install/browser
  /// and never leaving the device unencrypted.
  static Future<SimpleKeyPair> generateDeviceKeyPair() => _x25519.newKeyPair();

  static Future<SimpleKeyPair> keyPairFromPrivateKeyBase64(String base64Key) {
    return _x25519.newKeyPairFromSeed(base64Decode(base64Key));
  }

  static Future<String> privateKeyToBase64(SimpleKeyPair keyPair) async {
    return base64Encode(await keyPair.extractPrivateKeyBytes());
  }

  static Future<String> publicKeyToBase64(SimpleKeyPair keyPair) async {
    final pk = await keyPair.extractPublicKey();
    return base64Encode(pk.bytes);
  }

  /// A fresh random 32-byte symmetric key for a chat — generated once by
  /// whoever creates the chat, then sealed to every participant device.
  static Future<SecretKey> generateChatKey() => _cipher.newSecretKey();

  static String chatKeyToBase64(List<int> bytes) => base64Encode(bytes);

  static SecretKey chatKeyFromBase64(String base64Key) => SecretKey(base64Decode(base64Key));

  /// Seals [chatKeyBytes] so only the holder of [recipientPublicKeyBase64]'s
  /// matching private key can recover it. Protocol (must match
  /// crypto.js#sealToPublicKey exactly):
  ///   1. generate an ephemeral X25519 keypair
  ///   2. sharedSecret = X25519(ephemeralPrivate, recipientPublic)
  ///   3. key = BLAKE2b-256(sharedSecret || ephemeralPublic || recipientPublic)
  ///   4. ciphertext = ChaCha20-Poly1305(chatKeyBytes, key, nonce = 12 zero bytes)
  ///      — a fixed nonce is safe here because `key` is only ever used once
  ///        (derived fresh per seal call from a fresh ephemeral keypair)
  ///   5. output = base64(ephemeralPublic (32B) || ciphertext || mac (16B))
  static Future<String> sealToPublicKey({
    required List<int> chatKeyBytes,
    required String recipientPublicKeyBase64,
  }) async {
    final recipientPublicKey = SimplePublicKey(
      base64Decode(recipientPublicKeyBase64),
      type: KeyPairType.x25519,
    );
    final ephemeral = await _x25519.newKeyPair();
    final ephemeralPublicKey = await ephemeral.extractPublicKey();

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: recipientPublicKey,
    );
    final symmetricKey = await _deriveSymmetricKey(
      sharedSecret: await sharedSecret.extractBytes(),
      ephemeralPublicKey: ephemeralPublicKey.bytes,
      recipientPublicKey: recipientPublicKey.bytes,
    );

    final box = await _cipher.encrypt(
      chatKeyBytes,
      secretKey: symmetricKey,
      nonce: List.filled(12, 0),
    );

    final out = BytesBuilder()
      ..add(ephemeralPublicKey.bytes)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return base64Encode(out.toBytes());
  }

  /// Reverses [sealToPublicKey] using this device's own X25519 keypair.
  static Future<List<int>> unseal({
    required String sealedBase64,
    required SimpleKeyPair myKeyPair,
  }) async {
    final all = base64Decode(sealedBase64);
    final ephemeralPublicKeyBytes = all.sublist(0, 32);
    final cipherTextAndMac = all.sublist(32);
    final cipherText = cipherTextAndMac.sublist(0, cipherTextAndMac.length - 16);
    final macBytes = cipherTextAndMac.sublist(cipherTextAndMac.length - 16);

    final myPublicKey = await myKeyPair.extractPublicKey();
    final ephemeralPublicKey = SimplePublicKey(ephemeralPublicKeyBytes, type: KeyPairType.x25519);

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: ephemeralPublicKey,
    );
    final symmetricKey = await _deriveSymmetricKey(
      sharedSecret: await sharedSecret.extractBytes(),
      ephemeralPublicKey: ephemeralPublicKeyBytes,
      recipientPublicKey: myPublicKey.bytes,
    );

    return _cipher.decrypt(
      SecretBox(cipherText, nonce: List.filled(12, 0), mac: Mac(macBytes)),
      secretKey: symmetricKey,
    );
  }

  static Future<SecretKey> _deriveSymmetricKey({
    required List<int> sharedSecret,
    required List<int> ephemeralPublicKey,
    required List<int> recipientPublicKey,
  }) async {
    final input = BytesBuilder()
      ..add(sharedSecret)
      ..add(ephemeralPublicKey)
      ..add(recipientPublicKey);
    final digest = await _hash.hash(input.toBytes());
    return SecretKey(digest.bytes);
  }

  /// Encrypts message content with a chat's already-shared symmetric key.
  /// Output: base64(nonce (12B) || ciphertext || mac (16B)). A fresh random
  /// nonce every call — required since the same chatKey is reused across
  /// every message in the chat.
  static Future<String> encryptMessage({required String plainText, required SecretKey chatKey}) async {
    final box = await _cipher.encrypt(utf8.encode(plainText), secretKey: chatKey);
    final out = BytesBuilder()
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return base64Encode(out.toBytes());
  }

  static Future<String> decryptMessage({required String cipherTextBase64, required SecretKey chatKey}) async {
    final all = base64Decode(cipherTextBase64);
    final nonce = all.sublist(0, 12);
    final cipherTextAndMac = all.sublist(12);
    final cipherText = cipherTextAndMac.sublist(0, cipherTextAndMac.length - 16);
    final macBytes = cipherTextAndMac.sublist(cipherTextAndMac.length - 16);
    final clear = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: chatKey,
    );
    return utf8.decode(clear);
  }
}
