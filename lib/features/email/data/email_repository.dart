import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/api/multipart_helper.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/email_account.dart';
import '../../../models/email_message.dart';

class EmailPage {
  const EmailPage({required this.emails, required this.hasMore, required this.nextPage});

  final List<EmailMessage> emails;
  final bool hasMore;
  final int nextPage;
}

class EmailRepository {
  EmailRepository(this._dio);

  final Dio _dio;

  Future<List<EmailAccount>> getAccounts() async {
    try {
      final res = await _dio.get(Endpoints.emailAccounts);
      return asList(res.data['email_accounts'], (e) => EmailAccount.fromJson(asMap(e)));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Throws [ApiException] with a clean message on bad credentials/connection
  /// failure (backend validates via a real IMAP login before saving anything).
  /// The imap*/smtp* params are required by the backend only when
  /// [provider] is [EmailProvider.custom] (a user-supplied mailbox instead
  /// of the Gmail/Yahoo presets).
  Future<EmailAccount> connectAccount({
    required EmailProvider provider,
    required String emailAddress,
    required String appPassword,
    String? imapHost,
    int? imapPort,
    MailEncryption? imapEncryption,
    String? smtpHost,
    int? smtpPort,
    MailEncryption? smtpEncryption,
  }) async {
    try {
      final res = await _dio.post(Endpoints.emailAccounts, data: {
        'provider': provider.apiValue,
        'email_address': emailAddress,
        'app_password': appPassword,
        if (provider == EmailProvider.custom) ...{
          'imap_host': imapHost,
          'imap_port': imapPort,
          'imap_encryption': imapEncryption?.apiValue,
          'smtp_host': smtpHost,
          'smtp_port': smtpPort,
          'smtp_encryption': smtpEncryption?.apiValue,
        },
      });
      return EmailAccount.fromJson(asMap(res.data['email_account']));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Fetches new mail for this account over real IMAP — deliberately a
  /// separate call from [connectAccount], not bundled into it, since real
  /// mailbox I/O can be slow and previously caused connect requests to time
  /// out. Called when the inbox is opened and on pull-to-refresh instead.
  /// Uses a longer receive timeout than the app default (30s) since this is
  /// the one endpoint that's expected to do real, potentially-slow network
  /// I/O against a third-party mail server rather than our own API.
  Future<int> syncAccount(String id) async {
    try {
      final res = await _dio.post(
        Endpoints.syncEmailAccount(id),
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
      return asInt(res.data['new_count']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> disconnectAccount(String id) async {
    try {
      await _dio.delete(Endpoints.emailAccount(id));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Backend paginates via Laravel's `paginate()`, whose JSON envelope nests
  /// the actual rows under `data` alongside `current_page`/`last_page`.
  Future<EmailPage> getEmails(String accountId, {int page = 1}) async {
    try {
      final res = await _dio.get(Endpoints.accountEmails(accountId), queryParameters: {'page': page});
      final paginator = asMap(res.data['emails']);
      final emails = asList(paginator['data'], (e) => EmailMessage.fromJson(asMap(e)));
      final currentPage = asInt(paginator['current_page'], fallback: page);
      final lastPage = asInt(paginator['last_page'], fallback: currentPage);
      return EmailPage(emails: emails, hasMore: currentPage < lastPage, nextPage: currentPage + 1);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<EmailMessage> getEmail(String emailId) async {
    try {
      final res = await _dio.get(Endpoints.email(emailId));
      return EmailMessage.fromJson(asMap(res.data['email']));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// [to]/[cc] are comma-separated address lists (the backend splits and
  /// validates each one, so a friendly "Enter one or more valid email
  /// addresses" error comes back instead of a raw SMTP rejection).
  /// [attachmentPaths] are local file paths picked on-device; uploaded as a
  /// single multipart request alongside the message fields.
  Future<void> sendEmail(
    String accountId, {
    required String to,
    String? cc,
    required String subject,
    required String body,
    List<String> attachmentPaths = const [],
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final formData = await MultipartHelper.build(
        fields: {'to': to, if (cc != null && cc.isNotEmpty) 'cc': cc, 'subject': subject, 'body': body},
        multiFiles: attachmentPaths.isEmpty ? const {} : {'attachments[]': attachmentPaths},
      );
      await _dio.post(Endpoints.sendEmail(accountId), data: formData, onSendProgress: onSendProgress);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// [replyAll] asks the backend to also Cc everyone who was on the original
  /// To/Cc lines (minus this mailbox and the original sender) — [cc] is any
  /// *additional* manually-added recipients on top of that.
  Future<void> replyToEmail(
    String emailId, {
    required String body,
    bool replyAll = false,
    String? cc,
    List<String> attachmentPaths = const [],
    ProgressCallback? onSendProgress,
  }) async {
    try {
      final formData = await MultipartHelper.build(
        fields: {
          'body': body,
          'reply_all': replyAll,
          if (cc != null && cc.isNotEmpty) 'cc': cc,
        },
        multiFiles: attachmentPaths.isEmpty ? const {} : {'attachments[]': attachmentPaths},
      );
      await _dio.post(Endpoints.replyEmail(emailId), data: formData, onSendProgress: onSendProgress);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
