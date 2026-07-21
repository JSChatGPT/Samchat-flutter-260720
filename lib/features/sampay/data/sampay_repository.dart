import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/message.dart';
import '../../../models/sampay_account.dart';

class SampayRepository {
  SampayRepository(this._dio);

  final Dio _dio;

  Future<String> getLinkUrl() async {
    try {
      final res = await _dio.get(Endpoints.sampayLink);
      return asString(res.data['authorization_url']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<({bool isLinked, SampayAccount? account})> getStatus() async {
    try {
      final res = await _dio.get(Endpoints.sampayStatus);
      final isLinked = asBool(res.data['is_linked']);
      final accountJson = res.data['sampay_account'];
      return (
        isLinked: isLinked,
        account: accountJson is Map ? SampayAccount.fromJson(asMap(accountJson)) : null,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> unlink() async {
    try {
      await _dio.delete(Endpoints.sampayUnlink);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Map<String, dynamic>> validateRecipient(
    String chatId, {
    required String recipientType,
    required String recipientAccount,
    required double amount,
    required String purpose,
    String? remarks,
    String? recipientUserId,
  }) async {
    try {
      final res = await _dio.post(Endpoints.sampayValidateRecipient(chatId), data: {
        'recipient_type': recipientType,
        'recipient_account': recipientAccount,
        'amount': amount,
        'purpose': purpose,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        if (recipientUserId != null) 'recipient_user_id': recipientUserId,
      });
      return asMap(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Returns the created `payment_request` message — the server excludes
  /// the sender from its MessageSent broadcast (same "sender's own bubble
  /// comes from the REST response" rule as a normal text message), so the
  /// caller needs this to show the request immediately instead of only
  /// after the chat is reopened and re-fetched.
  Future<ChatMessage> requestPayment(
    String chatId, {
    required double amount,
    required String recipientType,
    required String recipientAccount,
    required String purpose,
    String? remarks,
    String? recipientUserId,
  }) async {
    try {
      final res = await _dio.post(Endpoints.sampayRequestChat(chatId), data: {
        'amount': amount,
        'recipient_type': recipientType,
        'recipient_account': recipientAccount,
        'purpose': purpose,
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        if (recipientUserId != null) 'recipient_user_id': recipientUserId,
      });
      return ChatMessage.fromJson(asMap(res.data['chat_message']), fallbackChatId: chatId);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> syncStatus(String chatId) async {
    try {
      await _dio.post(Endpoints.sampaySyncStatus(chatId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> approve(String chatId, String messageId) async {
    try {
      await _dio.post(Endpoints.sampayApprove(chatId, messageId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> reject(String chatId, String messageId) async {
    try {
      await _dio.post(Endpoints.sampayReject(chatId, messageId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
