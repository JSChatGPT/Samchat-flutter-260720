import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/chat.dart';
import '../../models/message.dart';

/// Local SQLite cache of chats/messages so previously-loaded conversations
/// stay viewable with no network — see InboxNotifier/ChatDetailNotifier for
/// the cache-then-network read pattern this backs.
///
/// Deliberately a thin "JSON blob per row" cache, not a normalized
/// relational schema: reading a row just re-runs the model's own
/// `fromJson` on the decoded blob, so there's exactly one source of truth
/// for each field's shape, not two competing ones. `ChatMessage.content`
/// here is always the already-decrypted (or placeholder) text exactly as
/// displayed — decryption happens once, at the repository boundary, well
/// before a message ever reaches this cache — so this file holds plaintext
/// at rest, the same way WhatsApp's own local database does; protecting it
/// is the OS's device-encryption job, not something layered on top here.
class ChatCacheService {
  ChatCacheService(this._db);

  final Database _db;

  static Future<ChatCacheService> open() async {
    final dbPath = await getDatabasesPath();
    final db = await openDatabase(
      '$dbPath/samchat_cache.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_chats (
            chat_id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            sort_key INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_cached_chats_sort ON cached_chats(sort_key)');

        await db.execute('''
          CREATE TABLE cached_messages (
            message_id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_cached_messages_chat ON cached_messages(chat_id, created_at)');
      },
    );
    return ChatCacheService(db);
  }

  Future<void> cacheChats(List<Chat> chats) async {
    final batch = _db.batch();
    for (final chat in chats) {
      final sortKey =
          (chat.lastMessage?.createdAt ?? chat.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .millisecondsSinceEpoch;
      batch.insert(
        'cached_chats',
        {'chat_id': chat.id, 'data': jsonEncode(chat.toJson()), 'sort_key': sortKey},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Chat>> getCachedChats() async {
    final rows = await _db.query('cached_chats', orderBy: 'sort_key DESC');
    return rows.map((row) => Chat.fromJson(jsonDecode(row['data'] as String))).toList();
  }

  /// Single-chat lookup — ChatDetailNotifier needs the Chat itself (group
  /// info, participants, block status), not just its messages, and the
  /// user will always have seen it in the inbox list (and so cached it via
  /// [cacheChats]) before ever opening it.
  Future<Chat?> getCachedChat(String chatId) async {
    final rows = await _db.query('cached_chats', where: 'chat_id = ?', whereArgs: [chatId], limit: 1);
    if (rows.isEmpty) return null;
    return Chat.fromJson(jsonDecode(rows.first['data'] as String));
  }

  Future<void> cacheMessages(String chatId, List<ChatMessage> messages) async {
    final batch = _db.batch();
    for (final message in messages) {
      _insertMessage(batch, chatId, message);
    }
    await batch.commit(noResult: true);
  }

  /// Single-message upsert — realtime arrivals and optimistic-send
  /// finalization go through here rather than [cacheMessages], which is
  /// for the batch case (initial load / pagination).
  Future<void> cacheMessage(ChatMessage message) async {
    final batch = _db.batch();
    _insertMessage(batch, message.chatId, message);
    await batch.commit(noResult: true);
  }

  void _insertMessage(Batch batch, String chatId, ChatMessage message) {
    batch.insert(
      'cached_messages',
      {
        'message_id': message.id,
        'chat_id': chatId,
        'data': jsonEncode(message.toJson()),
        'created_at': message.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Newest-first, matching the wire format ChatDetailNotifier already
  /// expects to reverse. Pass [beforeMillis] to page further back through
  /// already-cached history — the offline fallback for `loadMoreOlder`.
  Future<List<ChatMessage>> getCachedMessages(String chatId, {int limit = 50, int? beforeMillis}) async {
    final rows = await _db.query(
      'cached_messages',
      where: beforeMillis != null ? 'chat_id = ? AND created_at < ?' : 'chat_id = ?',
      whereArgs: beforeMillis != null ? [chatId, beforeMillis] : [chatId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((row) => ChatMessage.fromJson(jsonDecode(row['data'] as String))).toList();
  }

  Future<void> deleteMessage(String messageId) async {
    await _db.delete('cached_messages', where: 'message_id = ?', whereArgs: [messageId]);
  }

  Future<void> deleteChat(String chatId) async {
    await _db.delete('cached_chats', where: 'chat_id = ?', whereArgs: [chatId]);
    await _db.delete('cached_messages', where: 'chat_id = ?', whereArgs: [chatId]);
  }

  /// "Clear chat" — removes only the message history, keeps the chat's own
  /// cached row (its participants/group info are still valid, only the
  /// conversation content was wiped).
  Future<void> clearMessagesForChat(String chatId) async {
    await _db.delete('cached_messages', where: 'chat_id = ?', whereArgs: [chatId]);
  }

  /// Call on logout — a different account signing into the same device
  /// must never see the previous account's cached chats/messages.
  Future<void> clearAll() async {
    await _db.delete('cached_chats');
    await _db.delete('cached_messages');
  }
}
