import '../../models/message.dart';
import 'e2ee_service.dart';

/// Shared "decrypt at the boundary" rule for every place a [ChatMessage]
/// crosses from the wire into app state: MessagesRepository's REST/realtime
/// paths (the chat detail screen), and the inbox list's last-message preview
/// (both its initial REST load and its own separate MessageSent realtime
/// handler) — each of those fetches/decodes messages independently, so
/// without a shared helper each one silently reinvents (or forgets) this
/// exact fallback.
///
/// Never surfaces raw ciphertext in the UI — whether there's no key yet (key
/// distribution still in flight) or decryption outright failed, shows a
/// clear placeholder instead of base64 gibberish that reads as a broken app.
///
/// Recurses into [ChatMessage.quotedMessage] — a reply's quoted snippet is a
/// full nested ChatMessage with its own (possibly still-encrypted) content,
/// and was previously never decrypted here at all, so QuotedMessageWidget
/// rendered raw base64 ciphertext for any reply to an encrypted message
/// instead of the actual quoted text.
Future<ChatMessage> decryptChatMessage(E2eeService e2ee, ChatMessage message) async {
  final quoted = message.quotedMessage;
  final decryptedQuoted = quoted != null ? await decryptChatMessage(e2ee, quoted) : null;

  if (message.metadata['encrypted'] != true || message.content == null) {
    return decryptedQuoted != null ? message.copyWith(quotedMessage: decryptedQuoted) : message;
  }
  final decrypted = await e2ee.tryDecrypt(message.chatId, message.content!);
  return message.copyWith(
    content: decrypted ?? '🔒 Unable to decrypt this message',
    quotedMessage: decryptedQuoted,
  );
}
