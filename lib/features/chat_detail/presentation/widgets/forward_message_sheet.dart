import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_avatar.dart';
import '../../../../models/message.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../chats/application/inbox_notifier.dart';
import '../../application/chat_detail_notifier.dart';

/// Bottom sheet to pick a chat to forward [message] into. Reuses the
/// already-loaded inbox list rather than issuing a fresh fetch.
Future<void> showForwardMessageSheet(
  BuildContext context,
  WidgetRef ref, {
  required ChatMessage message,
}) async {
  final chats = ref.read(inboxNotifierProvider).chats;
  final myUserId = ref.read(currentUserIdProvider);

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Forward to…', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return ListTile(
                    leading: AppAvatar(
                      photoUrl: chat.avatarUrl(myUserId),
                      initials: chat.title(myUserId).substring(0, 1).toUpperCase(),
                    ),
                    title: Text(chat.title(myUserId)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (!context.mounted) return;
                      try {
                        final repo = ref.read(messagesRepositoryProvider);
                        // A text message might be E2EE-encrypted with THIS
                        // chat's key — the server-side forward endpoint just
                        // copies the stored ciphertext byte-for-byte, which
                        // the destination chat (different key) couldn't
                        // decrypt. Route through sendMessage instead, using
                        // the plaintext already decrypted client-side, so it
                        // gets re-encrypted correctly for the destination.
                        if (message.messageType == MessageType.text && message.content != null) {
                          await repo.sendMessage(
                            chatId: chat.id,
                            type: MessageType.text,
                            content: message.content,
                          );
                        } else {
                          await repo.forwardMessage(toChatId: chat.id, messageId: message.id);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Forwarded to ${chat.title(myUserId)}')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Forward failed: $e')));
                        }
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
