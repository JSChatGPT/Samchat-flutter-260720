import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/call.dart';

class CallsRepository {
  CallsRepository(this._dio);

  final Dio _dio;

  Future<CallRecord> initiate({String? receiverId, String? chatId, required CallType type}) async {
    try {
      final res = await _dio.post(Endpoints.calls, data: {
        'receiver_id': ?receiverId,
        'chat_id': ?chatId,
        'call_type': type == CallType.video ? 'video' : 'audio',
      });
      final json = res.data['call'] ?? res.data;
      return CallRecord.fromJson(asMap(json));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Short-lived Cloudflare Realtime TURN credentials for the next call's ICE
  /// servers (see CallController::turnCredentials on the backend) — minted
  /// per-request so no long-lived secret ships inside the app. Returns null
  /// (rather than throwing) when Cloudflare isn't configured or the request
  /// fails, so a caller can fall back to STUN-only instead of the whole call
  /// setup failing over a non-essential relay lookup.
  Future<Map<String, dynamic>?> turnCredentials() async {
    try {
      final res = await _dio.get(Endpoints.turnCredentials);
      final ice = res.data is Map ? res.data['iceServers'] : null;
      return ice is Map ? asMap(ice) : null;
    } on DioException {
      return null;
    }
  }

  Future<void> accept(String callId) => _post(Endpoints.acceptCall(callId));
  Future<void> decline(String callId) => _post(Endpoints.declineCall(callId));
  Future<void> end(String callId) => _post(Endpoints.endCall(callId));

  Future<void> join(String callId) => _post(Endpoints.joinCall(callId));

  Future<void> sendOffer(String callId, {required String targetId, required Map<String, dynamic> sdp}) {
    return _post(Endpoints.offerCall(callId), data: {'target_id': targetId, 'offer': sdp});
  }

  Future<void> sendAnswer(String callId, {required String targetId, required Map<String, dynamic> sdp}) {
    return _post(Endpoints.answerCall(callId), data: {'target_id': targetId, 'answer': sdp});
  }

  Future<void> sendCandidate(String callId, {required String targetId, required Map<String, dynamic> candidate}) {
    return _post(Endpoints.candidateCall(callId), data: {'target_id': targetId, 'candidate': candidate});
  }

  Future<void> _post(String path, {Map<String, dynamic>? data}) async {
    try {
      await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<CallRecord>> activeCalls() async {
    try {
      final res = await _dio.get(Endpoints.activeCalls);
      final raw = res.data is List ? res.data : res.data['calls'];
      return asList(raw, (e) => CallRecord.fromJson(asMap(e)));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<CallRecord>> history() async {
    try {
      final res = await _dio.get(Endpoints.calls);
      final raw = res.data is List ? res.data : res.data['calls'];
      return asList(raw, (e) => CallRecord.fromJson(asMap(e)));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> clearHistory() async {
    try {
      await _dio.delete(Endpoints.calls);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
