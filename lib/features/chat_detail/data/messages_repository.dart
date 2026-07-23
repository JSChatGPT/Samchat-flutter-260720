import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/multipart_helper.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../core/crypto/message_decryptor.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/chat.dart';
import '../../../models/message.dart';
import '../../../models/paginated_response.dart';

class MessagesRepository {
  MessagesRepository(this._dio, this._e2ee);

  final Dio _dio;
  final E2eeService _e2ee;

  /// Encryption/decryption is isolated entirely to this repository — the
  /// rest of the app (UI, models, realtime handlers) works with plain
  /// ChatMessage.content and never has to know a chat is encrypted. Messages
  /// sent before E2EE existed, or in a chat whose key hasn't finished
  /// distributing yet, have no `metadata.encrypted` flag and pass through
  /// untouched (backward compatibility — see the project plan).
  Future<ChatMessage> decryptIfNeeded(ChatMessage message) => decryptChatMessage(_e2ee, message);

  Future<List<ChatMessage>> decryptAll(List<ChatMessage> messages) async {
    final out = <ChatMessage>[];
    for (final m in messages) {
      out.add(await decryptIfNeeded(m));
    }
    return out;
  }

  /// Fetches chat detail + a page of messages. Opening page 1 also
  /// auto-marks unread messages from others as read server-side.
  Future<({Chat chat, PaginatedResponse<ChatMessage> messages})> getChatDetail(
    String chatId, {
    int page = 1,
  }) async {
    try {
      final res = await _dio.get(Endpoints.chat(chatId), queryParameters: {'page': page});
      final chat = Chat.fromJson(asMap(res.data['chat'] ?? res.data));
      final messagesRaw = res.data['messages'];
      PaginatedResponse<ChatMessage> messages;
      if (messagesRaw is Map) {
        messages = PaginatedResponse.fromJson(
          asMap(messagesRaw),
          (json) => ChatMessage.fromJson(json, fallbackChatId: chatId),
        );
        messages = PaginatedResponse(
          items: await decryptAll(messages.items),
          currentPage: messages.currentPage,
          lastPage: messages.lastPage,
          hasMore: messages.hasMore,
        );
      } else {
        final items = await decryptAll(
          asList(messagesRaw, (e) => ChatMessage.fromJson(asMap(e), fallbackChatId: chatId)),
        );
        messages = PaginatedResponse(items: items, currentPage: 1, lastPage: 1, hasMore: false);
      }
      return (chat: chat, messages: messages);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ChatMessage> sendMessage({
    required String chatId,
    required MessageType type,
    String? content,
    String? attachmentPath,
    Map<String, dynamic>? metadata,
    String? quotedMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      var outgoingContent = content;
      final outgoingMetadata = {...?metadata};
      if (content != null && content.isNotEmpty) {
        final encrypted = await _e2ee.tryEncrypt(chatId, content);
        if (encrypted != null) {
          outgoingContent = encrypted;
          outgoingMetadata['encrypted'] = true;
        }
      }

      final data = await MultipartHelper.build(
        fields: {
          'message_type': messageTypeToString(type),
          if (outgoingContent != null && outgoingContent.isNotEmpty) 'content': outgoingContent,
          if (outgoingMetadata.isNotEmpty) 'metadata': outgoingMetadata,
          'quoted_message_id': ?quotedMessageId,
        },
        files: attachmentPath != null ? {'attachment': attachmentPath} : const {},
      );
      final res = await _dio.post(
        Endpoints.messages(chatId),
        data: data,
        onSendProgress: onSendProgress,
      );
      final json = res.data['message'] ?? res.data;
      // The server echoes back exactly what was stored (ciphertext, if we
      // just encrypted) — return the plaintext version we already have
      // locally instead of round-tripping it through decrypt again.
      final serverMessage = ChatMessage.fromJson(asMap(json), fallbackChatId: chatId);
      return outgoingContent != content ? serverMessage.copyWith(content: content) : serverMessage;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<MessageReaction>> react(String messageId, String emoji) async {
    try {
      final res = await _dio.post(Endpoints.reactToMessage(messageId), data: {'emoji': emoji});
      return asList(res.data['reactions'], (e) => MessageReaction.fromJson(asMap(e)));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> markRead(String messageId) async {
    try {
      await _dio.post(Endpoints.markMessageRead(messageId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteMessage(String messageId, {required bool forEveryone}) async {
    try {
      await _dio.delete(
        Endpoints.deleteMessage(messageId),
        queryParameters: {'type': forEveryone ? 'everyone' : 'me'},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> bulkDelete(String chatId, List<String> messageIds, {required bool forEveryone}) async {
    try {
      await _dio.delete(
        Endpoints.bulkDeleteMessages(chatId),
        data: {'message_ids': messageIds, 'type': forEveryone ? 'everyone' : 'me'},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> clearChat(String chatId) async {
    try {
      await _dio.delete(Endpoints.clearChatMessages(chatId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ChatMessage> forwardMessage({required String toChatId, required String messageId}) async {
    try {
      final res = await _dio.post(
        Endpoints.forwardMessage(toChatId),
        data: {'message_id': messageId},
      );
      final json = res.data['message'] ?? res.data;
      return await decryptIfNeeded(ChatMessage.fromJson(asMap(json), fallbackChatId: toChatId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> setTyping(String chatId, bool isTyping) async {
    try {
      await _dio.post(Endpoints.typing(chatId), data: {'is_typing': isTyping});
    } on DioException catch (_) {
      // Typing indicator failures are non-critical — never surface to the UI.
    }
  }
}
