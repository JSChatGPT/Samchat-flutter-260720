import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'chat_backup_provider.dart';

/// Google Drive `appDataFolder`-backed [ChatBackupProvider] — a hidden,
/// per-app storage space (invisible in the user's normal Drive UI, doesn't
/// count against their visible storage quota, only this app can read it)
/// tied to whichever Google account they sign into here. Same mechanism
/// WhatsApp itself uses on Android for its own backups.
///
/// Deliberately hand-rolls the handful of Drive v3 REST calls it needs with
/// `dio` rather than pulling in the full `googleapis` package — this app
/// already prefers small hand-rolled clients over heavy SDKs (see the
/// hand-rolled Pusher client and its rationale in `pubspec.yaml`).
///
/// Requires a one-time setup step in Google Cloud Console for the
/// `samchatog` Firebase/GCP project: enable the Google Drive API, and
/// create an OAuth 2.0 Android client ID (package name + release/debug
/// SHA-1). Without that, `authenticate()`/`authorizeScopes()` below fail —
/// this class can't do that setup itself.
class AndroidDriveBackupProvider implements ChatBackupProvider {
  AndroidDriveBackupProvider({Dio? dio}) : _dio = dio ?? Dio();

  static const _scopes = ['https://www.googleapis.com/auth/drive.appdata'];
  static const _backupFileName = 'samchat_e2ee_backup.json';
  static const _filesUrl = 'https://www.googleapis.com/drive/v3/files';
  static const _uploadUrl = 'https://www.googleapis.com/upload/drive/v3/files';

  final Dio _dio;
  bool _initialized = false;
  GoogleSignInAccount? _account;
  String? _cachedFileId;

  @override
  bool get isSupported => true;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    // GoogleSignIn.instance.initialize() must be called exactly once for
    // the app's lifetime (per package docs) — guarded here since this
    // provider can be constructed more than once (Riverpod), but the
    // underlying GoogleSignIn.instance is itself already a static
    // singleton shared across every instance of this class.
    await GoogleSignIn.instance.initialize();
    _initialized = true;
  }

  /// Signs in (silently resuming a prior session where possible,
  /// interactively otherwise) and returns a valid Drive-appdata-scoped
  /// access token. Must be called from a user-interaction context (a button
  /// press) — both the interactive sign-in and the scope-authorization
  /// prompt require that on Android.
  Future<String> _accessToken() async {
    await _ensureInitialized();
    var account = _account ??= await GoogleSignIn.instance.attemptLightweightAuthentication();
    account ??= await GoogleSignIn.instance.authenticate();
    _account = account;

    final client = account.authorizationClient;
    final authorization =
        await client.authorizationForScopes(_scopes) ?? await client.authorizeScopes(_scopes);
    return authorization.accessToken;
  }

  Future<Map<String, String>> _authHeader() async {
    return {'Authorization': 'Bearer ${await _accessToken()}'};
  }

  Future<String?> _findBackupFileId() async {
    if (_cachedFileId != null) return _cachedFileId;
    final res = await _dio.get(
      _filesUrl,
      queryParameters: {
        'spaces': 'appDataFolder',
        'q': "name = '$_backupFileName' and trashed = false",
        'fields': 'files(id)',
      },
      options: Options(headers: await _authHeader()),
    );
    final files = (res.data['files'] as List?) ?? const [];
    if (files.isEmpty) return null;
    _cachedFileId = files.first['id'] as String;
    return _cachedFileId;
  }

  @override
  Future<bool> hasBackup() async {
    try {
      return await _findBackupFileId() != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> upload(String encryptedBlob) async {
    final existingId = await _findBackupFileId();
    final headers = await _authHeader();

    if (existingId != null) {
      await _dio.patch(
        '$_uploadUrl/$existingId',
        queryParameters: {'uploadType': 'media'},
        data: encryptedBlob,
        options: Options(headers: {...headers, 'Content-Type': 'application/json'}),
      );
      return;
    }

    final form = FormData.fromMap({
      'metadata': MultipartFile.fromString(
        jsonEncode({
          'name': _backupFileName,
          'parents': ['appDataFolder'],
        }),
        contentType: DioMediaType('application', 'json'),
      ),
      'file': MultipartFile.fromString(encryptedBlob, contentType: DioMediaType('application', 'json')),
    });
    final res = await _dio.post(
      _uploadUrl,
      queryParameters: {'uploadType': 'multipart'},
      data: form,
      options: Options(headers: headers),
    );
    _cachedFileId = res.data['id'] as String?;
  }

  @override
  Future<String?> download() async {
    final fileId = await _findBackupFileId();
    if (fileId == null) return null;
    final res = await _dio.get<String>(
      '$_filesUrl/$fileId',
      queryParameters: {'alt': 'media'},
      options: Options(headers: await _authHeader(), responseType: ResponseType.plain),
    );
    return res.data;
  }

  @override
  Future<void> delete() async {
    final fileId = await _findBackupFileId();
    if (fileId == null) return;
    await _dio.delete('$_filesUrl/$fileId', options: Options(headers: await _authHeader()));
    _cachedFileId = null;
  }
}
