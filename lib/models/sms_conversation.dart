import '../core/utils/json_utils.dart';

/// A native SMS thread from `content://sms`, grouped by `thread_id`.
class SmsConversation {
  const SmsConversation({
    required this.threadId,
    required this.address,
    this.displayName,
    required this.snippet,
    required this.date,
    required this.unreadCount,
  });

  final String threadId;
  final String address;
  final String? displayName;
  final String snippet;
  final DateTime date;
  final int unreadCount;

  String get title => (displayName != null && displayName!.isNotEmpty) ? displayName! : address;

  SmsConversation copyWith({int? unreadCount}) {
    return SmsConversation(
      threadId: threadId,
      address: address,
      displayName: displayName,
      snippet: snippet,
      date: date,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  factory SmsConversation.fromMap(Map<dynamic, dynamic> raw) {
    final map = asMap(raw);
    return SmsConversation(
      threadId: asString(map['threadId']),
      address: asString(map['address']),
      displayName: asStringOrNull(map['displayName']),
      snippet: asString(map['snippet']),
      date: DateTime.fromMillisecondsSinceEpoch(asInt(map['date'])),
      unreadCount: asInt(map['unreadCount']),
    );
  }
}
