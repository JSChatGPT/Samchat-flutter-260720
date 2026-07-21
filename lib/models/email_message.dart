import '../core/utils/json_utils.dart';
import 'email_attachment.dart';

class EmailMessage {
  const EmailMessage({
    required this.id,
    required this.emailAccountId,
    required this.folder,
    this.fromAddress,
    this.fromName,
    this.toAddress,
    this.ccAddress,
    this.messageId,
    required this.subject,
    this.bodyText,
    this.bodyHtml,
    required this.isRead,
    required this.isOutgoing,
    required this.receivedAt,
    this.attachmentsCount = 0,
    this.attachments = const [],
  });

  final String id;
  final String emailAccountId;
  final String folder;
  final String? fromAddress;
  final String? fromName;
  final String? toAddress;
  final String? ccAddress;
  final String? messageId;
  final String subject;
  final String? bodyText;
  final String? bodyHtml;
  final bool isRead;
  final bool isOutgoing;
  final DateTime receivedAt;
  final int attachmentsCount;
  final List<EmailAttachment> attachments;

  String get senderDisplay => (fromName != null && fromName!.isNotEmpty) ? fromName! : (fromAddress ?? 'Unknown');
  String get snippet => (bodyText ?? '').replaceAll('\n', ' ').trim();
  bool get hasAttachments => attachmentsCount > 0 || attachments.isNotEmpty;

  EmailMessage copyWith({bool? isRead}) {
    return EmailMessage(
      id: id,
      emailAccountId: emailAccountId,
      folder: folder,
      fromAddress: fromAddress,
      fromName: fromName,
      toAddress: toAddress,
      ccAddress: ccAddress,
      messageId: messageId,
      subject: subject,
      bodyText: bodyText,
      bodyHtml: bodyHtml,
      isRead: isRead ?? this.isRead,
      isOutgoing: isOutgoing,
      receivedAt: receivedAt,
      attachmentsCount: attachmentsCount,
      attachments: attachments,
    );
  }

  factory EmailMessage.fromJson(Map<String, dynamic> json) {
    return EmailMessage(
      id: asString(json['id']),
      emailAccountId: asString(json['email_account_id']),
      folder: asString(json['folder'], fallback: 'INBOX'),
      fromAddress: asStringOrNull(json['from_address']),
      fromName: asStringOrNull(json['from_name']),
      toAddress: asStringOrNull(json['to_address']),
      ccAddress: asStringOrNull(json['cc_address']),
      messageId: asStringOrNull(json['message_id']),
      subject: asString(json['subject'], fallback: '(no subject)'),
      bodyText: asStringOrNull(json['body_text']),
      bodyHtml: asStringOrNull(json['body_html']),
      isRead: asBool(json['is_read']),
      isOutgoing: asBool(json['is_outgoing']),
      receivedAt: asDateTimeOrNull(json['received_at']) ?? DateTime.now(),
      attachmentsCount: asInt(json['attachments_count']),
      attachments: asList(json['attachments'], (e) => EmailAttachment.fromJson(asMap(e))),
    );
  }
}
