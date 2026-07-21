import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/crypto/e2ee_service.dart';
import '../../../core/crypto/message_decryptor.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/chat.dart';

enum InboxFilter { all, unread, groups }

class ChatsRepository {
  ChatsRepository(this._dio, this._e2ee);

  final Dio _dio;
  final E2eeService _e2ee;

  Future<({List<Chat> chats, List<String> blockedUserIds})> getChats({
    InboxFilter filter = InboxFilter.all,
    String? search,
  }) async {
    try {
      final res = await _dio.get(Endpoints.chats, queryParameters: {
        if (filter == InboxFilter.unread) 'filter': 'unread',
        if (filter == InboxFilter.groups) 'filter': 'groups',
        if (search != null && search.isNotEmpty) 'search': search,
      });
      final chats = asList(res.data['chats'], (e) => Chat.fromJson(asMap(e)));
      // The inbox's last-message preview is a separate fetch from the chat
      // detail screen's own message list — it needs the same
      // decrypt-at-the-boundary treatment or an encrypted chat's preview
      // renders as raw ciphertext even though opening the chat itself
      // decrypts fine.
      final decryptedChats = await Future.wait(chats.map((chat) async {
        final lastMessage = chat.lastMessage;
        if (lastMessage == null) return chat;
        return chat.copyWith(lastMessage: await decryptChatMessage(_e2ee, lastMessage));
      }));
      final blocked = asList(res.data['blocked_user_ids'], (e) => e.toString());
      return (chats: decryptedChats, blockedUserIds: blocked);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<Chat> createOrGetDirectChat(String userId) async {
    try {
      final res = await _dio.post(Endpoints.chats, data: {'user_id': userId});
      final json = res.data['chat'] ?? res.data;
      final chat = Chat.fromJson(asMap(json));
      // Idempotent (see E2eeService.distributeNewChatKey) — safe to call on
      // every open of this chat, not just genuinely new ones. Awaited (not
      // fire-and-forget) so the very first message sent right after opening
      // a brand-new chat doesn't race ahead of key distribution and get
      // sent as plaintext.
      await _e2ee.distributeNewChatKey(chat.id, chat.participants.map((p) => p.userId).toList());
      return chat;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      await _dio.delete(Endpoints.chat(chatId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<bool> toggleMute(String chatId) async {
    try {
      final res = await _dio.post(Endpoints.muteChat(chatId));
      return asBool(res.data['is_muted']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
