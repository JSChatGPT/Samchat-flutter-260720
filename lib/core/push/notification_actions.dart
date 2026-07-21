import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/endpoints.dart';
import '../config/app_config.dart';
import '../crypto/e2ee_repository.dart';
import '../crypto/e2ee_service.dart';
import '../storage/secure_storage_service.dart';

/// Handles notification action-button taps — WhatsApp-style "Reply" on a
/// message/email notification, "Decline" on an incoming call.
///
/// Deliberately self-contained (its own Dio + secure storage + E2EE stack)
/// rather than reaching into the running app's Riverpod tree: this must work
/// identically whether the app process is alive, backgrounded, or fully
/// killed. In the killed case, flutter_local_notifications dispatches to a
/// disposable background isolate with no access to any existing
/// ProviderContainer — so both the foreground and background response paths
/// (see local_notifications_service.dart) route through this same function.
@pragma('vm:entry-point')
Future<void> handleNotificationAction(NotificationResponse response) async {
  final payload = response.payload;
  final actionId = response.actionId;
  final input = response.input?.trim();
  if (payload == null) return;

  final parts = payload.split(':');
  if (parts.isEmpty) return;
  final kind = parts[0];

  final dio = await _buildAuthedDio();
  if (dio == null) return;

  try {
    if (kind == 'message' && actionId == 'reply' && parts.length >= 2 && input != null && input.isNotEmpty) {
      await _replyToChat(dio, chatId: parts[1], text: input);
    } else if (kind == 'new_email' &&
        actionId == 'reply' &&
        parts.length >= 3 &&
        input != null &&
        input.isNotEmpty) {
      await dio.post(Endpoints.replyEmail(parts[2]), data: {'body': input});
    } else if (kind == 'incoming_call' && actionId == 'decline' && parts.length >= 2) {
      await dio.post(Endpoints.declineCall(parts[1]));
    }
  } catch (_) {
    // Best-effort — the user can always retry from inside the app.
  }
}

/// Resolves the real preview text for a 'message' push. The server can only
/// ever send a generic placeholder for an encrypted chat (see
/// SendMessagePushNotification::bodyFor on the backend) since it never has
/// the E2EE key — this decrypts client-side using the ciphertext the backend
/// includes in the data payload precisely so this is possible, the same way
/// opening the chat itself would decrypt it.
Future<String> decryptPushMessageBody(Map<String, dynamic> data, {required String fallback}) async {
  final chatId = data['chat_id']?.toString();
  final content = data['content']?.toString();
  final isEncrypted = data['encrypted']?.toString() == '1';
  if (!isEncrypted || chatId == null || chatId.isEmpty || content == null || content.isEmpty) {
    return fallback;
  }
  try {
    final dio = await _buildAuthedDio();
    if (dio == null) return fallback;
    final e2ee = E2eeService(storage: SecureStorageService(), repository: E2eeRepository(dio));
    await e2ee.loadLocalIdentity();
    final decrypted = await e2ee.tryDecrypt(chatId, content);
    return decrypted ?? fallback;
  } catch (_) {
    return fallback;
  }
}

Future<Dio?> _buildAuthedDio() async {
  final storage = SecureStorageService();
  final token = await storage.readToken();
  if (token == null) return null;
  return Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
  ));
}

/// Mirrors MessagesRepository.sendMessage's encrypt-then-send behavior for a
/// plain text message — the app's chats are E2EE (see e2ee_service.dart), so
/// a reply sent from here needs the same encrypt-before-send step or it
/// would leak as plaintext into an otherwise-encrypted chat.
Future<void> _replyToChat(Dio dio, {required String chatId, required String text}) async {
  final e2ee = E2eeService(storage: SecureStorageService(), repository: E2eeRepository(dio));
  await e2ee.loadLocalIdentity();

  var content = text;
  final metadata = <String, dynamic>{};
  final encrypted = await e2ee.tryEncrypt(chatId, text);
  if (encrypted != null) {
    content = encrypted;
    metadata['encrypted'] = true;
  }

  await dio.post(Endpoints.messages(chatId), data: {
    'message_type': 'text',
    'content': content,
    if (metadata.isNotEmpty) 'metadata': metadata,
  });
}
