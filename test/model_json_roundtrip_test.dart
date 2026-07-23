import 'package:flutter_test/flutter_test.dart';
import 'package:samchat_flutter/models/chat.dart';
import 'package:samchat_flutter/models/chat_participant.dart';
import 'package:samchat_flutter/models/group.dart';
import 'package:samchat_flutter/models/message.dart';
import 'package:samchat_flutter/models/user.dart';

void main() {
  test('ChatMessage round-trips through toJson/fromJson', () {
    final original = ChatMessage(
      id: 'msg-1',
      chatId: 'chat-1',
      senderId: 'user-1',
      sender: const AppUser(id: 'user-1', firstName: 'Ada', lastSeenAt: null),
      messageType: MessageType.text,
      content: 'hello there',
      metadata: const {'encrypted': true},
      quotedMessageId: 'msg-0',
      quotedMessage: ChatMessage(
        id: 'msg-0',
        chatId: 'chat-1',
        senderId: 'user-2',
        messageType: MessageType.text,
        content: 'original message',
        createdAt: DateTime.utc(2026, 1, 1, 10),
      ),
      createdAt: DateTime.utc(2026, 1, 1, 12, 30),
      isReadByRecipient: true,
      reactions: const [MessageReaction(userId: 'user-2', emoji: '👍')],
    );

    final roundTripped = ChatMessage.fromJson(original.toJson());

    expect(roundTripped.id, original.id);
    expect(roundTripped.chatId, original.chatId);
    expect(roundTripped.senderId, original.senderId);
    expect(roundTripped.sender?.firstName, 'Ada');
    expect(roundTripped.content, 'hello there');
    expect(roundTripped.quotedMessage?.content, 'original message');
    expect(roundTripped.createdAt.isAtSameMomentAs(original.createdAt), true);
    expect(roundTripped.isReadByRecipient, true);
    expect(roundTripped.reactions, hasLength(1));
    expect(roundTripped.reactions.first.emoji, '👍');
  });

  test('Chat (group) round-trips through toJson/fromJson', () {
    final original = Chat(
      id: 'chat-1',
      isGroup: true,
      group: const ChatGroup(id: 'chat-1', groupName: 'Team', onlyAdminsCanPost: true),
      participants: [
        ChatParticipant(userId: 'user-1', user: const AppUser(id: 'user-1', username: 'ada'), isAdmin: true),
        ChatParticipant(userId: 'user-2', user: const AppUser(id: 'user-2', username: 'bob')),
      ],
      lastMessage: ChatMessage(
        id: 'msg-1',
        chatId: 'chat-1',
        senderId: 'user-1',
        messageType: MessageType.text,
        content: 'hi team',
        createdAt: DateTime.utc(2026, 1, 1, 12),
      ),
      unreadCount: 3,
      isMuted: true,
      updatedAt: DateTime.utc(2026, 1, 1, 12),
    );

    final roundTripped = Chat.fromJson(original.toJson());

    expect(roundTripped.id, original.id);
    expect(roundTripped.isGroup, true);
    expect(roundTripped.group?.groupName, 'Team');
    expect(roundTripped.group?.onlyAdminsCanPost, true);
    expect(roundTripped.participants, hasLength(2));
    expect(roundTripped.participants.first.user.username, 'ada');
    expect(roundTripped.lastMessage?.content, 'hi team');
    expect(roundTripped.unreadCount, 3);
    expect(roundTripped.isMuted, true);
    expect(roundTripped.updatedAt!.isAtSameMomentAs(original.updatedAt!), true);
  });

  test('Chat (direct) round-trips through toJson/fromJson', () {
    final original = Chat(
      id: 'chat-2',
      isGroup: false,
      participants: [
        ChatParticipant(userId: 'user-1', user: const AppUser(id: 'user-1', username: 'ada')),
        ChatParticipant(userId: 'user-2', user: const AppUser(id: 'user-2', username: 'bob')),
      ],
      unreadCount: 0,
    );

    final roundTripped = Chat.fromJson(original.toJson());

    expect(roundTripped.isGroup, false);
    expect(roundTripped.group, isNull);
    expect(roundTripped.otherParticipant('user-1')?.user.username, 'bob');
  });
}
