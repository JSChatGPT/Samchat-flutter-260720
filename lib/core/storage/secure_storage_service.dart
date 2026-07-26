import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:samchat_telecom/samchat_telecom.dart';

import '../utils/json_utils.dart';
import '../../models/user.dart';

/// Sanctum bearer token storage — Keychain on iOS, EncryptedSharedPreferences
/// on Android. Never put the token in shared_preferences.
class SecureStorageService {
  SecureStorageService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _cachedUserKey = 'auth_cached_user';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  /// Also mirrors the token into a plain native store (see samchat_telecom)
  /// so a Decline tapped on the incoming-call notification can make its one
  /// HTTP call entirely natively, without needing the Flutter engine to be
  /// running at all — every write/clear goes through here or [clear], so
  /// there's no separate call site that could forget to keep it in sync.
  Future<void> writeToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    unawaited(SamchatTelecom.syncAuthToken(token));
  }

  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  Future<void> writeUserId(String id) => _storage.write(key: _userIdKey, value: id);

  /// The signed-in user's last-known profile — lets AuthNotifier restore a
  /// full `authenticated` state instantly from disk on cold start, instead
  /// of gating the whole app on a `GET /user` round trip (see
  /// AuthNotifier._restoreSession). Written on every successful login and
  /// every successful background profile refresh; never assumed fresh —
  /// it's a starting point the network is still asked to confirm/update.
  Future<AppUser?> readCachedUser() async {
    final json = await _storage.read(key: _cachedUserKey);
    if (json == null) return null;
    try {
      return AppUser.fromJson(asMap(jsonDecode(json)));
    } catch (_) {
      // Corrupt/unparseable — treat exactly like "no cache", never crash
      // startup over it.
      return null;
    }
  }

  Future<void> writeCachedUser(AppUser user) {
    return _storage.write(key: _cachedUserKey, value: jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _cachedUserKey);
    unawaited(SamchatTelecom.syncAuthToken(null));
  }

  /// Generic passthrough, used by the E2EE key store (device_id, X25519
  /// private key) — deliberately not token/userId-specific like the rest of
  /// this class, since those are the only two callers that need arbitrary keys.
  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
}
