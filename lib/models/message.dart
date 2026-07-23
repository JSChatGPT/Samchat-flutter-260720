import '../core/utils/json_utils.dart';
import '../core/utils/url_utils.dart';
import 'user.dart';

enum MessageType { text, image, video, audio, file, sticker, callLog, paymentRequest, unknown }

MessageType messageTypeFromString(String? raw) {
  switch (raw) {
    case 'text':
      return MessageType.text;
    case 'image':
      return MessageType.image;
    case 'video':
      return MessageType.video;
    case 'audio':
      return MessageType.audio;
    case 'file':
      return MessageType.file;
    case 'sticker':
      return MessageType.sticker;
    case 'call_log':
      return MessageType.callLog;
    case 'payment_request':
      return MessageType.paymentRequest;
    default:
      return MessageType.unknown;
  }
}

String messageTypeToString(MessageType type) {
  switch (type) {
    case MessageType.text:
      return 'text';
    case MessageType.image:
      return 'image';
    case MessageType.video:
      return 'video';
    case MessageType.audio:
      return 'audio';
    case MessageType.file:
      return 'file';
    case MessageType.sticker:
      return 'sticker';
    case MessageType.callLog:
      return 'call_log';
    case MessageType.paymentRequest:
      return 'payment_request';
    case MessageType.unknown:
      return 'text';
  }
}

/// A single user's reaction to a message (one per user per message — see
/// ChatDetailNotifier.toggleReaction for the toggle/replace semantics).
class MessageReaction {
  const MessageReaction({required this.userId, required this.emoji});

  final String userId;
  final String emoji;

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      userId: asString(json['user_id']),
      emoji: asString(json['emoji']),
    );
  }
}

/// Local-only send lifecycle for optimistic UI — the server itself only has
/// the concept of "sent" (row exists) and "read" (a read receipt).
enum SendStatus { sending, sent, read, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.sender,
    required this.messageType,
    this.content,
    this.mediaUrl,
    this.fileName,
    this.mimeType,
    this.metadata = const {},
    this.quotedMessageId,
    this.quotedMessage,
    required this.createdAt,
    this.isReadByRecipient = false,
    this.sendStatus = SendStatus.sent,
    this.clientTempId,
    this.deletedForMe = false,
    this.reactions = const [],
  });

  final String id;
  final String chatId;
  final String senderId;
  final AppUser? sender;
  final MessageType messageType;
  final String? content;
  final String? mediaUrl;
  final String? fileName;
  final String? mimeType;
  final Map<String, dynamic> metadata;
  final String? quotedMessageId;
  final ChatMessage? quotedMessage;
  final DateTime createdAt;
  final bool isReadByRecipient;
  final SendStatus sendStatus;
  final String? clientTempId;
  final bool deletedForMe;
  final List<MessageReaction> reactions;

  bool isMine(String myUserId) => senderId == myUserId;

  String get previewText {
    switch (messageType) {
      case MessageType.text:
        return content ?? '';
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎤 Voice note';
      case MessageType.file:
        return '📎 ${fileName ?? 'File'}';
      case MessageType.sticker:
        return '${content ?? '🩵'} Sticker';
      case MessageType.callLog:
        return '📞 Call';
      case MessageType.paymentRequest:
        return '💰 Payment';
      case MessageType.unknown:
        return content ?? '';
    }
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? fallbackChatId}) {
    final metadata = asMap(json['metadata']);
    final senderJson = json['sender'];
    return ChatMessage(
      id: asString(json['id']),
      chatId: asStringOrNull(json['chat_id']) ?? fallbackChatId ?? '',
      senderId: asString(json['sender_id']),
      sender: senderJson is Map ? AppUser.fromJson(asMap(senderJson)) : null,
      messageType: messageTypeFromString(asStringOrNull(json['message_type'])),
      content: asStringOrNull(json['content']),
      mediaUrl: normalizeMediaUrl(asStringOrNull(json['media_url'] ?? metadata['media_url'])),
      fileName: asStringOrNull(json['file_name'] ?? metadata['file_name']),
      mimeType: asStringOrNull(json['mime_type'] ?? metadata['mime_type']),
      metadata: metadata,
      quotedMessageId: asStringOrNull(json['quoted_message_id']),
      quotedMessage: json['quoted_message'] is Map
          ? ChatMessage.fromJson(asMap(json['quoted_message']), fallbackChatId: fallbackChatId)
          : null,
      createdAt: asDateTimeOrNull(json['created_at']) ?? DateTime.now(),
      isReadByRecipient: asBool(json['is_read']) || asStringOrNull(json['read_at']) != null,
      sendStatus: SendStatus.sent,
      reactions: asList(json['reactions'], (e) => MessageReaction.fromJson(asMap(e))),
    );
  }

  ChatMessage copyWith({
    SendStatus? sendStatus,
    String? id,
    bool? isReadByRecipient,
    bool? deletedForMe,
    String? content,
    List<MessageReaction>? reactions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId,
      senderId: senderId,
      sender: sender,
      messageType: messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl,
      fileName: fileName,
      mimeType: mimeType,
      metadata: metadata,
      quotedMessageId: quotedMessageId,
      quotedMessage: quotedMessage,
      createdAt: createdAt,
      isReadByRecipient: isReadByRecipient ?? this.isReadByRecipient,
      sendStatus: sendStatus ?? this.sendStatus,
      clientTempId: clientTempId,
      deletedForMe: deletedForMe ?? this.deletedForMe,
      reactions: reactions ?? this.reactions,
    );
  }
}
