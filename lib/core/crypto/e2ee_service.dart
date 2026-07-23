import 'dart:async';
import 'dart:io' show Platform;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import '../storage/secure_storage_service.dart';
import 'e2ee_primitives.dart';
import 'e2ee_repository.dart';

/// Orchestrates this app's E2EE: device identity/keypair lifecycle, chat-key
/// generation/distribution/caching, and the encrypt/decrypt convenience
/// methods `MessagesRepository` calls at the send/receive boundary.
///
/// Security model and known limitations are documented on [E2eePrimitives]
/// and in the project plan — no forward secrecy, no re-keying on membership
/// change, multi-device = independent keypairs per device.
class E2eeService {
  E2eeService({required SecureStorageService storage, required E2eeRepository repository})
      : _storage = storage,
        _repository = repository;

  final SecureStorageService _storage;
  final E2eeRepository _repository;

  static const _deviceIdKey = 'e2ee_device_id';
  static const _privateKeyKey = 'e2ee_private_key';
  static const _chatKeyPrefix = 'e2ee_chat_key_';

  String? _deviceId;
  SimpleKeyPair? _keyPair;
  final Map<String, SecretKey> _chatKeyCache = {};
  final Set<String> _pendingKeyRequests = {};

  String get platform {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }

  /// True once this device already has an identity in secure storage — a
  /// normal cold start of an existing install. False right after a fresh
  /// install/reinstall/new phone, before [ensureDeviceRegistered] has run —
  /// the one moment it's worth checking for a cloud backup to restore from
  /// instead of silently generating a brand-new, unrelated identity (see
  /// ChatBackupService).
  Future<bool> hasLocalIdentity() async {
    return await _storage.read(_privateKeyKey) != null;
  }

  /// This device's identity, ready to hand to [ChatBackupCrypto.encrypt] —
  /// null if [ensureDeviceRegistered] hasn't run yet this session.
  Future<({String deviceId, String privateKeyBase64})?> exportIdentityForBackup() async {
    final deviceId = _deviceId ?? await _storage.read(_deviceIdKey);
    final keyPair = _keyPair;
    final privateKeyBase64 =
        keyPair != null ? await E2eePrimitives.privateKeyToBase64(keyPair) : await _storage.read(_privateKeyKey);
    if (deviceId == null || privateKeyBase64 == null) return null;
    return (deviceId: deviceId, privateKeyBase64: privateKeyBase64);
  }

  /// Writes a recovered identity into secure storage — call before
  /// [ensureDeviceRegistered] on a device with no local identity yet (see
  /// [hasLocalIdentity]) when a cloud backup was found and successfully
  /// decrypted. Restoring the *same* device_id/keypair means the backend's
  /// existing chat_key_grants for this identity's public key work
  /// immediately, with no waiting on the self-heal path at all.
  Future<void> restoreIdentityFromBackup({required String deviceId, required String privateKeyBase64}) async {
    await _storage.write(_privateKeyKey, privateKeyBase64);
    await _storage.write(_deviceIdKey, deviceId);
    _deviceId = deviceId;
    _keyPair = await E2eePrimitives.keyPairFromPrivateKeyBase64(privateKeyBase64);
  }

  /// Call once per app session (after login) — generates this device's
  /// identity/keypair on first run, or loads it from secure storage, then
  /// makes sure the backend has the current public key.
  Future<void> ensureDeviceRegistered() async {
    var deviceId = await _storage.read(_deviceIdKey);
    deviceId ??= const Uuid().v4();
    _deviceId = deviceId;

    final storedPrivateKey = await _storage.read(_privateKeyKey);
    if (storedPrivateKey != null) {
      _keyPair = await E2eePrimitives.keyPairFromPrivateKeyBase64(storedPrivateKey);
    } else {
      _keyPair = await E2eePrimitives.generateDeviceKeyPair();
      await _storage.write(_privateKeyKey, await E2eePrimitives.privateKeyToBase64(_keyPair!));
      await _storage.write(_deviceIdKey, deviceId);
    }

    final publicKeyBase64 = await E2eePrimitives.publicKeyToBase64(_keyPair!);
    await _repository.registerDeviceKey(
      deviceId: deviceId,
      publicKeyBase64: publicKeyBase64,
      platform: platform,
    );
  }

  /// Populates [_deviceId]/[_keyPair] from local storage only — no network
  /// call to re-register the public key. Sufficient for anything that only
  /// needs the local identity to encrypt/decrypt with an already-established
  /// chat key (getChatKey/tryEncrypt/tryDecrypt); [ensureDeviceRegistered]'s
  /// extra registration round-trip is unneeded once a device has registered
  /// once during normal app use, and skipping it matters in a time-boxed
  /// context like a notification quick-reply, where Android gives a
  /// background broadcast receiver only a few seconds to finish before
  /// killing it — every avoidable network call is a chance to lose the race.
  Future<void> loadLocalIdentity() async {
    final deviceId = await _storage.read(_deviceIdKey);
    final storedPrivateKey = await _storage.read(_privateKeyKey);
    if (deviceId != null && storedPrivateKey != null) {
      _deviceId = deviceId;
      _keyPair = await E2eePrimitives.keyPairFromPrivateKeyBase64(storedPrivateKey);
      return;
    }
    // No local identity yet at all (e.g. replying to the very first
    // notification before ever opening the app) — fall back to the full,
    // network-registering flow.
    await ensureDeviceRegistered();
  }

  /// Generates a brand-new chat key and seals it to every device of every
  /// participant (including the creator's own device) — call right after
  /// creating a direct chat or group.
  ///
  /// Idempotent by design: `createOrGetDirectChat` is a create-or-return
  /// call, so this gets invoked on every open of an existing 1:1 chat too,
  /// not just genuinely new ones. If this device already has a grant for
  /// the chat, a key was already distributed (by this device or another
  /// participant's) — generating a new one here would silently orphan
  /// everyone else's copy, so bail out instead.
  ///
  /// Critically, this also bails out if the CHAT already has a key
  /// established by ANY device (not just this one) — a device whose local
  /// identity resets (reinstall — a brand-new device_id/keypair,
  /// indistinguishable server-side from a genuinely new device) has no
  /// local key either, but the chat itself is very much already keyed.
  /// Without this check such a device would generate and upload a
  /// competing key, overwriting every other participant's grant and
  /// permanently orphaning every message already encrypted under the real
  /// one — confirmed to actually happen: a real chat's key was silently
  /// regenerated this way, wiping decrypt access to its entire history for
  /// both participants. A reset device just has to wait — the next message
  /// anyone else sends reseals the real key to it via healMissingGrants.
  Future<void> distributeNewChatKey(String chatId, List<String> participantUserIds) async {
    if (await getChatKey(chatId) != null) return;
    if (await _repository.chatHasEstablishedKey(chatId)) return;

    final chatKey = await E2eePrimitives.generateChatKey();
    final chatKeyBytes = await chatKey.extractBytes();

    final grants = <Map<String, String>>[];
    for (final userId in participantUserIds) {
      final deviceKeys = await _repository.getDeviceKeysForUser(userId);
      for (final device in deviceKeys) {
        final sealed = await E2eePrimitives.sealToPublicKey(
          chatKeyBytes: chatKeyBytes,
          recipientPublicKeyBase64: device.publicKeyBase64,
        );
        grants.add({'user_id': userId, 'device_id': device.deviceId, 'sealed_key': sealed});
      }
    }
    if (grants.isEmpty) return; // no registered device keys yet — chat stays plaintext until they upgrade
    await _repository.uploadChatKeyGrants(chatId, grants);

    _chatKeyCache[chatId] = chatKey;
    await _storage.write('$_chatKeyPrefix$chatId', E2eePrimitives.chatKeyToBase64(chatKeyBytes));
  }

  /// Reseals this chat's already-shared key to a newly-added member's
  /// devices — call right after ChatController::addParticipants succeeds.
  /// Requires this device to already hold the chat's key (i.e. the adder
  /// must already be a participant).
  Future<void> distributeKeyToNewMember(String chatId, String newUserId) async {
    final chatKey = await getChatKey(chatId);
    if (chatKey == null) return; // this chat isn't encrypted (yet) — nothing to distribute
    final chatKeyBytes = await chatKey.extractBytes();

    final deviceKeys = await _repository.getDeviceKeysForUser(newUserId);
    if (deviceKeys.isEmpty) return;

    final grants = <Map<String, String>>[];
    for (final device in deviceKeys) {
      final sealed = await E2eePrimitives.sealToPublicKey(
        chatKeyBytes: chatKeyBytes,
        recipientPublicKeyBase64: device.publicKeyBase64,
      );
      grants.add({'user_id': newUserId, 'device_id': device.deviceId, 'sealed_key': sealed});
    }
    await _repository.uploadChatKeyGrants(chatId, grants);
  }

  /// Null means this chat has no key yet for this device — the caller
  /// should treat the chat as not-yet-encrypted (plaintext), matching the
  /// backward-compatibility rule documented on the backend's `metadata
  /// ->> 'encrypted'` flag.
  Future<SecretKey?> getChatKey(String chatId) async {
    final cached = _chatKeyCache[chatId];
    if (cached != null) return cached;

    final stored = await _storage.read('$_chatKeyPrefix$chatId');
    if (stored != null) {
      final key = E2eePrimitives.chatKeyFromBase64(stored);
      _chatKeyCache[chatId] = key;
      return key;
    }

    final deviceId = _deviceId;
    final keyPair = _keyPair;
    if (deviceId == null || keyPair == null) return null;

    final sealed = await _repository.getMyChatKeyGrant(chatId, deviceId);
    if (sealed == null) return null;

    final bytes = await E2eePrimitives.unseal(sealedBase64: sealed, myKeyPair: keyPair);
    final key = SecretKey(bytes);
    _chatKeyCache[chatId] = key;
    await _storage.write('$_chatKeyPrefix$chatId', E2eePrimitives.chatKeyToBase64(bytes));
    return key;
  }

  /// Returns null (leave as plaintext) if this chat has no key yet.
  Future<String?> tryEncrypt(String chatId, String plainText) async {
    final key = await getChatKey(chatId);
    if (key == null) return null;
    // Fire-and-forget: opportunistically repairs any participant device
    // missing a grant (see healMissingGrants) — never blocks or fails the
    // actual send.
    unawaited(healMissingGrants(chatId).catchError((_) {}));
    return E2eePrimitives.encryptMessage(plainText: plainText, chatKey: key);
  }

  /// Reseals this chat's key to any participant device that doesn't have a
  /// grant for it yet — the self-healing counterpart to
  /// [distributeNewChatKey]/[distributeKeyToNewMember]. A device only ever
  /// gets a grant at the moment a chat's key is first created, or when it's
  /// added as a participant/new device — nothing re-checks this afterwards,
  /// so a device whose local identity resets (a reinstall generates a brand
  /// new device_id/keypair, indistinguishable server-side from a genuinely
  /// new device) permanently loses access to that chat's key otherwise.
  /// Called from [tryEncrypt] on every send; cheap (the backend only ever
  /// returns genuinely missing devices) and self-correcting — the next
  /// message sent by anyone who still has access repairs every other
  /// participant's stale/missing devices.
  Future<void> healMissingGrants(String chatId) async {
    // Falls back to the storage-backed getChatKey (not just the in-memory
    // cache) since this is also called from handleGrantRequest, reacting to
    // a realtime event for a chat that may not have been opened yet this
    // session — the key can be sitting in secure storage without ever
    // having been loaded into _chatKeyCache.
    final chatKey = _chatKeyCache[chatId] ?? await getChatKey(chatId);
    if (chatKey == null) return;
    final chatKeyBytes = await chatKey.extractBytes();

    final missing = await _repository.getMissingDeviceGrants(chatId);
    if (missing.isEmpty) return;

    final grants = <Map<String, String>>[];
    for (final device in missing) {
      final sealed = await E2eePrimitives.sealToPublicKey(
        chatKeyBytes: chatKeyBytes,
        recipientPublicKeyBase64: device.publicKeyBase64,
      );
      grants.add({'user_id': device.userId, 'device_id': device.deviceId, 'sealed_key': sealed});
    }
    await _repository.uploadChatKeyGrants(chatId, grants);
  }

  /// Returns null if this chat has no key (caller should fall back to
  /// treating the content as already-plaintext).
  Future<String?> tryDecrypt(String chatId, String cipherTextBase64) async {
    final key = await ensureChatKeyAvailable(chatId);
    if (key == null) return null;
    try {
      return await E2eePrimitives.decryptMessage(cipherTextBase64: cipherTextBase64, chatKey: key);
    } catch (_) {
      return null;
    }
  }

  /// Like [getChatKey], but when THIS device has no grant yet for a chat
  /// that's already keyed — the exact state after a reinstall, new phone,
  /// or fresh web login, before this device's own device-key has been
  /// resealed to by anyone — asks every other currently-connected device to
  /// reseal it right now (see requestKeyGrant/ChatKeyGrantRequested) and
  /// waits briefly for the reply instead of leaving every message in the
  /// chat permanently stuck behind "Unable to decrypt this message" until
  /// someone happens to send something new.
  ///
  /// Only the first miss for a given chat pays this wait: once the grant
  /// lands, getChatKey's own cache/storage make every subsequent call (in
  /// this same decryptAll batch or later) resolve immediately.
  Future<SecretKey?> ensureChatKeyAvailable(String chatId) async {
    var key = await getChatKey(chatId);
    if (key != null) return key;
    if (!await _repository.chatHasEstablishedKey(chatId)) return null; // genuinely unencrypted chat — not an error

    if (_pendingKeyRequests.add(chatId)) {
      unawaited(
        _repository.requestKeyGrant(chatId).catchError((_) {}).whenComplete(
              () => _pendingKeyRequests.remove(chatId),
            ),
      );
    }

    for (var i = 0; i < 4; i++) {
      await Future.delayed(const Duration(seconds: 2));
      key = await getChatKey(chatId);
      if (key != null) return key;
    }
    return null;
  }

  /// Reacts to another of this chat's devices (often this very user, on a
  /// different device) asking to be resealed — see requestKeyGrant. A no-op
  /// on any device that doesn't itself hold the key, including the
  /// requesting device hearing its own broadcast echoed back to it.
  Future<void> handleGrantRequest(String chatId) => healMissingGrants(chatId);
}
