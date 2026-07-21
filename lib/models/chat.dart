import '../core/utils/json_utils.dart';
import 'chat_participant.dart';
import 'group.dart';
import 'message.dart';

class Chat {
  const Chat({
    required this.id,
    required this.isGroup,
    this.group,
    this.participants = const [],
    this.lastMessage,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isBlocked = false,
    this.blockedByMe = false,
    this.updatedAt,
  });

  final String id;
  final bool isGroup;
  final ChatGroup? group;
  final List<ChatParticipant> participants;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool isMuted;
  final bool isBlocked;
  final bool blockedByMe;
  final DateTime? updatedAt;

  /// The other participant in a direct chat (null for groups).
  ChatParticipant? otherParticipant(String myUserId) {
    if (isGroup) return null;
    for (final p in participants) {
      if (p.userId != myUserId) return p;
    }
    return participants.isNotEmpty ? participants.first : null;
  }

  String title(String myUserId) {
    if (isGroup) return group?.groupName ?? 'Group';
    return otherParticipant(myUserId)?.user.displayName ?? 'Unknown';
  }

  String? avatarUrl(String myUserId) {
    if (isGroup) return group?.groupImageUrl;
    return otherParticipant(myUserId)?.user.photoUrl;
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    final groupJson = json['group'];
    final id = asString(json['id']);

    // The inbox list (`GET /chats`) nests the caller's own mute/unread state
    // under `pivot` and embeds recent messages as a flat `messages` array
    // (last element = most recent) rather than a single `last_message` key —
    // fall back to the flatter shape too in case another endpoint differs.
    final pivot = asMap(json['pivot']);
    final messagesList = asList(json['messages'], (e) => ChatMessage.fromJson(asMap(e), fallbackChatId: id));
    final lastMessageJson = json['last_message'];

    return Chat(
      id: id,
      isGroup: groupJson is Map,
      group: groupJson is Map ? ChatGroup.fromJson(asMap(groupJson)) : null,
      participants: asList(json['participants'], (e) => ChatParticipant.fromJson(asMap(e))),
      lastMessage: lastMessageJson is Map
          ? ChatMessage.fromJson(asMap(lastMessageJson), fallbackChatId: id)
          : (messagesList.isNotEmpty ? messagesList.last : null),
      unreadCount: asInt(pivot.isNotEmpty ? pivot['unread_count'] : json['unread_count']),
      isMuted: asBool(pivot.isNotEmpty ? pivot['is_muted'] : json['is_muted']),
      isBlocked: asBool(json['is_blocked']),
      blockedByMe: asBool(json['blocked_by_me']),
      updatedAt: asDateTimeOrNull(json['last_message_at'] ?? json['updated_at']),
    );
  }

  Chat copyWith({ChatMessage? lastMessage, int? unreadCount, bool? isMuted}) {
    return Chat(
      id: id,
      isGroup: isGroup,
      group: group,
      participants: participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isBlocked: isBlocked,
      blockedByMe: blockedByMe,
      updatedAt: updatedAt,
    );
  }
}
