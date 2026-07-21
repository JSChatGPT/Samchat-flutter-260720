import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/native/app_intent_channel.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../models/message.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../chat_detail/application/chat_detail_notifier.dart';
import '../../application/inbox_notifier.dart';

/// "Share to SamChat" landing screen — lets the user pick which existing
/// chat to forward the shared text/image into (the WhatsApp-style share
/// sheet target from IntentRouter.kt / AppIntentChannel).
class ShareTargetScreen extends ConsumerStatefulWidget {
  const ShareTargetScreen({super.key, required this.intent});

  final AppIntent intent;

  @override
  ConsumerState<ShareTargetScreen> createState() => _ShareTargetScreenState();
}

class _ShareTargetScreenState extends ConsumerState<ShareTargetScreen> {
  String? _sendingChatId;

  Future<void> _sendTo(String chatId) async {
    setState(() => _sendingChatId = chatId);
    final notifier = ref.read(chatDetailNotifierProvider(chatId).notifier);
    try {
      if (widget.intent.text != null) {
        await notifier.sendMessage(type: MessageType.text, content: widget.intent.text);
      }
      for (final path in widget.intent.paths ?? const <String>[]) {
        final isImage = widget.intent.mimeType?.startsWith('image/') ?? false;
        await notifier.sendMessage(type: isImage ? MessageType.image : MessageType.file, attachmentPath: path);
      }
      if (mounted) context.pushReplacementNamed(RouteNames.chatDetail, pathParameters: {'chatId': chatId});
    } catch (e) {
      if (mounted) {
        setState(() => _sendingChatId = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inboxNotifierProvider);
    final myUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Share to')),
      body: switch (state.status) {
        InboxLoadStatus.loading => const Center(child: CircularProgressIndicator()),
        InboxLoadStatus.error => ErrorStateWidget(
            message: state.error ?? 'Could not load chats',
            onRetry: () => ref.invalidate(inboxNotifierProvider),
          ),
        InboxLoadStatus.loaded => state.chats.isEmpty
            ? const EmptyStateWidget(icon: Icons.forward_outlined, title: 'No chats to share to yet')
            : ListView.builder(
                itemCount: state.chats.length,
                itemBuilder: (context, index) {
                  final chat = state.chats[index];
                  final other = !chat.isGroup ? chat.otherParticipant(myUserId) : null;
                  final busy = _sendingChatId == chat.id;
                  return ListTile(
                    leading: AppAvatar(
                      photoUrl: chat.avatarUrl(myUserId),
                      initials: chat.isGroup
                          ? chat.title(myUserId).substring(0, 1).toUpperCase()
                          : (other?.user.initials ?? '?'),
                    ),
                    title: Text(chat.title(myUserId), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : null,
                    onTap: _sendingChatId == null ? () => _sendTo(chat.id) : null,
                  );
                },
              ),
      },
    );
  }
}
