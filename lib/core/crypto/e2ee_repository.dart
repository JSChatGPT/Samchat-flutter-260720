import 'package:dio/dio.dart';

import '../api/api_exception.dart';
import '../utils/json_utils.dart';

class DeviceKeyInfo {
  const DeviceKeyInfo({required this.deviceId, required this.publicKeyBase64});
  final String deviceId;
  final String publicKeyBase64;
}

class MissingDeviceGrant {
  const MissingDeviceGrant({required this.userId, required this.deviceId, required this.publicKeyBase64});
  final String userId;
  final String deviceId;
  final String publicKeyBase64;
}

class E2eeRepository {
  E2eeRepository(this._dio);

  final Dio _dio;

  Future<void> registerDeviceKey({
    required String deviceId,
    required String publicKeyBase64,
    required String platform,
  }) async {
    try {
      await _dio.post('/device-keys', data: {
        'device_id': deviceId,
        'public_key': publicKeyBase64,
        'platform': platform,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<DeviceKeyInfo>> getDeviceKeysForUser(String userId) async {
    try {
      final res = await _dio.get('/users/$userId/device-keys');
      final raw = asList(res.data['device_keys'], asMap);
      return raw
          .map((m) => DeviceKeyInfo(deviceId: asString(m['device_id']), publicKeyBase64: asString(m['public_key'])))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Each entry: {user_id, device_id, sealed_key (base64)}.
  Future<void> uploadChatKeyGrants(String chatId, List<Map<String, String>> grants) async {
    try {
      await _dio.post('/chats/$chatId/keys', data: {'grants': grants});
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Null if this device hasn't been granted a key for this chat yet.
  Future<String?> getMyChatKeyGrant(String chatId, String deviceId) async {
    try {
      final res = await _dio.get('/chats/$chatId/keys/mine', queryParameters: {'device_id': deviceId});
      return asStringOrNull(res.data['sealed_key']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDioError(e);
    }
  }

  /// Whether this chat already has a key established by ANY participant
  /// device — see E2eeService.distributeNewChatKey.
  Future<bool> chatHasEstablishedKey(String chatId) async {
    try {
      final res = await _dio.get('/chats/$chatId/keys/exists');
      return asBool(res.data['exists']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Asks every other currently-connected device (including this user's OWN
  /// other devices — the common case is this very user switching phones or
  /// logging into web) to reseal this chat's key to this device right now.
  /// See E2eeService.ensureChatKeyAvailable.
  Future<void> requestKeyGrant(String chatId) async {
    try {
      await _dio.post('/chats/$chatId/keys/request');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Every registered device, across every current participant, missing a
  /// grant for this chat's key — see E2eeService.healMissingGrants.
  Future<List<MissingDeviceGrant>> getMissingDeviceGrants(String chatId) async {
    try {
      final res = await _dio.get('/chats/$chatId/keys/missing-devices');
      final raw = asList(res.data['devices'], asMap);
      return raw
          .map((m) => MissingDeviceGrant(
                userId: asString(m['user_id']),
                deviceId: asString(m['device_id']),
                publicKeyBase64: asString(m['public_key']),
              ))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
