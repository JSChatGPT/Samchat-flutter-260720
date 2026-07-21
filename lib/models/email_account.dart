import '../core/utils/json_utils.dart';

enum EmailProvider { gmail, yahoo, custom }

EmailProvider emailProviderFromString(String? raw) {
  switch (raw) {
    case 'yahoo':
      return EmailProvider.yahoo;
    case 'custom':
      return EmailProvider.custom;
    default:
      return EmailProvider.gmail;
  }
}

extension EmailProviderX on EmailProvider {
  String get apiValue => switch (this) {
        EmailProvider.yahoo => 'yahoo',
        EmailProvider.custom => 'custom',
        EmailProvider.gmail => 'gmail',
      };

  String get label => switch (this) {
        EmailProvider.yahoo => 'Yahoo Mail',
        EmailProvider.custom => 'Custom (IMAP/SMTP)',
        EmailProvider.gmail => 'Gmail',
      };
}

enum MailEncryption { ssl, tls, starttls, none }

extension MailEncryptionX on MailEncryption {
  String get apiValue => name;
  String get label => switch (this) {
        MailEncryption.ssl => 'SSL',
        MailEncryption.tls => 'TLS',
        MailEncryption.starttls => 'STARTTLS',
        MailEncryption.none => 'None',
      };
}

class EmailAccount {
  const EmailAccount({
    required this.id,
    required this.provider,
    required this.emailAddress,
    this.lastSyncedAt,
    this.unreadCount = 0,
  });

  final String id;
  final EmailProvider provider;
  final String emailAddress;
  final DateTime? lastSyncedAt;
  final int unreadCount;

  factory EmailAccount.fromJson(Map<String, dynamic> json) {
    return EmailAccount(
      id: asString(json['id']),
      provider: emailProviderFromString(asStringOrNull(json['provider'])),
      emailAddress: asString(json['email_address']),
      lastSyncedAt: asDateTimeOrNull(json['last_synced_at']),
      unreadCount: asInt(json['unread_count']),
    );
  }

  EmailAccount copyWith({int? unreadCount}) {
    return EmailAccount(
      id: id,
      provider: provider,
      emailAddress: emailAddress,
      lastSyncedAt: lastSyncedAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
