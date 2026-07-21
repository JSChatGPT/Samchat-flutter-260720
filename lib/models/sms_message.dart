import '../core/utils/json_utils.dart';

/// A single row from `content://sms` for one thread.
class SmsMessage {
  const SmsMessage({
    required this.id,
    required this.address,
    required this.body,
    required this.date,
    required this.outgoing,
    this.threadId,
  });

  final String id;
  final String address;
  final String body;
  final DateTime date;
  final bool outgoing;

  /// Only present on messages pushed live via the incoming-message stream —
  /// [SmsRepository.getMessages] omits it since the caller already knows
  /// which thread it asked for.
  final String? threadId;

  factory SmsMessage.fromMap(Map<dynamic, dynamic> raw) {
    final map = asMap(raw);
    return SmsMessage(
      id: asString(map['id']),
      address: asString(map['address']),
      body: asString(map['body']),
      date: DateTime.fromMillisecondsSinceEpoch(asInt(map['date'])),
      outgoing: asBool(map['outgoing']),
      threadId: asStringOrNull(map['threadId']),
    );
  }
}
