import 'package:flutter_test/flutter_test.dart';
import 'package:samchat_flutter/core/cache/chat_cache_service.dart';
import 'package:samchat_flutter/models/chat.dart';
import 'package:samchat_flutter/models/chat_participant.dart';
import 'package:samchat_flutter/models/message.dart';
import 'package:samchat_flutter/models/user.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ChatCacheService cache;

  setUp(() async {
    cache = await ChatCacheService.open();
    await cache.clearAll();
  });

  test('caches and retrieves chats, sorted newest-first', () async {
    final chatA = Chat(
      id: 'chat-a',
      isGroup: false,
      participants: [ChatParticipant(userId: 'u1', user: const AppUser(id: 'u1', username: 'ada'))],
      lastMessage: ChatMessage(
        id: 'm1',
        chatId: 'chat-a',
        senderId: 'u1',
        messageType: MessageType.text,
        content: 'older',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    final chatB = Chat(
      id: 'chat-b',
      isGroup: false,
      participants: [ChatParticipant(userId: 'u2', user: const AppUser(id: 'u2', username: 'bob'))],
      lastMessage: ChatMessage(
        id: 'm2',
        chatId: 'chat-b',
        senderId: 'u2',
        messageType: MessageType.text,
        content: 'newer',
        createdAt: DateTime(2026, 1, 2),
      ),
    );

    await cache.cacheChats([chatA, chatB]);
    final result = await cache.getCachedChats();

    expect(result.map((c) => c.id), ['chat-b', 'chat-a']);
  });

  test('upserts a chat on re-cache instead of duplicating', () async {
    const chat = Chat(id: 'chat-a', isGroup: false, unreadCount: 1);
    await cache.cacheChats([chat]);
    await cache.cacheChats([chat.copyWith(unreadCount: 5)]);

    final result = await cache.getCachedChats();
    expect(result, hasLength(1));
    expect(result.first.unreadCount, 5);
  });

  test('caches and retrieves messages for a chat, newest-first', () async {
    final messages = [
      ChatMessage(
        id: 'm1',
        chatId: 'chat-a',
        senderId: 'u1',
        messageType: MessageType.text,
        content: 'first',
        createdAt: DateTime(2026, 1, 1, 10),
      ),
      ChatMessage(
        id: 'm2',
        chatId: 'chat-a',
        senderId: 'u1',
        messageType: MessageType.text,
        content: 'second',
        createdAt: DateTime(2026, 1, 1, 11),
      ),
      ChatMessage(
        id: 'm3',
        chatId: 'chat-a',
        senderId: 'u1',
        messageType: MessageType.text,
        content: 'third',
        createdAt: DateTime(2026, 1, 1, 12),
      ),
    ];
    await cache.cacheMessages('chat-a', messages);

    final result = await cache.getCachedMessages('chat-a');
    expect(result.map((m) => m.content), ['third', 'second', 'first']);
  });

  test('getCachedMessages respects beforeMillis for pagination fallback', () async {
    final messages = [
      ChatMessage(
        id: 'm1',
        chatId: 'chat-a',
        senderId: 'u1',
        messageType: MessageType.text,
        content: 'first',
        createdAt: DateTime(2026, 1, 1, 10),
      ),
      ChatMessage(
        id: 'm2',
        chatId: 'chat-a',
        senderId: 'u1',
        messageType: MessageType.text,
        content: 'second',
        createdAt: DateTime(2026, 1, 1, 11),
      ),
    ];
    await cache.cacheMessages('chat-a', messages);

    final beforeSecond = DateTime(2026, 1, 1, 11).millisecondsSinceEpoch;
    final result = await cache.getCachedMessages('chat-a', beforeMillis: beforeSecond);
    expect(result.map((m) => m.content), ['first']);
  });

  test('cacheMessage upserts a single message', () async {
    final message = ChatMessage(
      id: 'm1',
      chatId: 'chat-a',
      senderId: 'u1',
      messageType: MessageType.text,
      content: 'v1',
      createdAt: DateTime(2026, 1, 1),
    );
    await cache.cacheMessage(message);
    await cache.cacheMessage(message.copyWith(content: 'v2'));

    final result = await cache.getCachedMessages('chat-a');
    expect(result, hasLength(1));
    expect(result.first.content, 'v2');
  });

  test('deleteChat removes both the chat and its messages', () async {
    const chat = Chat(id: 'chat-a', isGroup: false);
    final message = ChatMessage(
      id: 'm1',
      chatId: 'chat-a',
      senderId: 'u1',
      messageType: MessageType.text,
      content: 'hi',
      createdAt: DateTime(2026, 1, 1),
    );
    await cache.cacheChats([chat]);
    await cache.cacheMessage(message);

    await cache.deleteChat('chat-a');

    expect(await cache.getCachedChats(), isEmpty);
    expect(await cache.getCachedMessages('chat-a'), isEmpty);
  });

  test('clearAll wipes everything', () async {
    await cache.cacheChats([const Chat(id: 'chat-a', isGroup: false)]);
    await cache.cacheMessage(ChatMessage(
      id: 'm1',
      chatId: 'chat-a',
      senderId: 'u1',
      messageType: MessageType.text,
      content: 'hi',
      createdAt: DateTime(2026, 1, 1),
    ));

    await cache.clearAll();

    expect(await cache.getCachedChats(), isEmpty);
    expect(await cache.getCachedMessages('chat-a'), isEmpty);
  });
}
