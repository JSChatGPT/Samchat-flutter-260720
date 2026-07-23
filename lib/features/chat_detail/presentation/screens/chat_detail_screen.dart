import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/push/push_service.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/emoji_picker_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../models/chat_participant.dart';
import '../../../../models/message.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../sampay/application/sampay_request_notifier.dart';
import '../../../settings/application/profile_notifier.dart';
import '../../../sampay/presentation/widgets/payment_recipient_picker_sheet.dart';
import '../../../sampay/presentation/widgets/send_payment_sheet.dart';
import '../../application/chat_detail_notifier.dart';
import '../widgets/attachment_picker_sheet.dart';
import '../widgets/date_separator.dart';
import '../widgets/forward_message_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_composer.dart';
import '../widgets/share_message_sheet.dart';
import '../widgets/quoted_message_widget.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _scrollController = ScrollController();
  ChatMessage? _replyingTo;
  // Captured in initState — `ref` itself cannot be used inside dispose().
  late final PushService _pushService;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _pushService = ref.read(pushServiceProvider);
    _pushService.currentlyOpenChatId = widget.chatId;
  }

  @override
  void dispose() {
    if (_pushService.currentlyOpenChatId == widget.chatId) {
      _pushService.currentlyOpenChatId = null;
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels <= 200) {
      ref.read(chatDetailNotifierProvider(widget.chatId).notifier).loadMoreOlder();
    }
  }

  void _send(String text) {
    ref.read(chatDetailNotifierProvider(widget.chatId).notifier).sendMessage(
          type: MessageType.text,
          content: text,
          quotedMessageId: _replyingTo?.id,
        );
    setState(() => _replyingTo = null);
  }

  Future<void> _pickAttachment() async {
    final result = await showAttachmentPickerSheet(context);
    if (result == null || !mounted) return;
    await ref.read(chatDetailNotifierProvider(widget.chatId).notifier).sendMessage(
          type: result.type,
          attachmentPath: result.path,
          metadata: result.fileName != null ? {'file_name': result.fileName} : null,
          quotedMessageId: _replyingTo?.id,
        );
    if (mounted) setState(() => _replyingTo = null);
  }

  void _sendVoiceNote(String path, Duration duration) {
    ref.read(chatDetailNotifierProvider(widget.chatId).notifier).sendMessage(
          type: MessageType.audio,
          attachmentPath: path,
          metadata: {'duration_seconds': duration.inSeconds},
          quotedMessageId: _replyingTo?.id,
        );
    setState(() => _replyingTo = null);
  }

  void _sendSticker(String emoji) {
    ref.read(chatDetailNotifierProvider(widget.chatId).notifier).sendMessage(
          type: MessageType.sticker,
          content: emoji,
          quotedMessageId: _replyingTo?.id,
        );
    setState(() => _replyingTo = null);
  }

  static const _quickReactEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  Future<void> _openFullEmojiReactionPicker(ChatMessage message) async {
    final scheme = Theme.of(context).colorScheme;
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (ctx) => SizedBox(
        height: 320,
        child: EmojiPicker(
          onEmojiSelected: (category, e) => Navigator.pop(ctx, e.emoji),
          config: emojiPickerConfig(scheme, height: 300),
        ),
      ),
    );
    if (emoji != null && mounted) {
      ref.read(chatDetailNotifierProvider(widget.chatId).notifier).toggleReaction(message, emoji);
    }
  }

  void _showMessageActions(ChatMessage message, bool isMine) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final emoji in _quickReactEmojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.pop(ctx);
                        ref.read(chatDetailNotifierProvider(widget.chatId).notifier).toggleReaction(message, emoji);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.pop(ctx);
                      _openFullEmojiReactionPicker(message);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward_outlined),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(ctx);
                showForwardMessageSheet(context, ref, message: message);
              },
            ),
            if (message.messageType == MessageType.text) ...[
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: message.content ?? ''));
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('Share via'),
                onTap: () {
                  Navigator.pop(ctx);
                  showShareViaSheet(context, text: message.content ?? '');
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for me'),
              onTap: () async {
                Navigator.pop(ctx);
                if (!mounted) return;
                await ref
                    .read(chatDetailNotifierProvider(widget.chatId).notifier)
                    .deleteMessage(message, forEveryone: false);
              },
            ),
            if (isMine)
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
                title: Text('Delete for everyone', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  await ref
                      .read(chatDetailNotifierProvider(widget.chatId).notifier)
                      .deleteMessage(message, forEveryone: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSendPayment(ChatDetailState state, String myUserId, ChatParticipant? other) async {
    final chat = state.chat;
    if (chat == null) return;
    var recipient = other;
    if (chat.isGroup) {
      recipient = await pickPaymentRecipient(context, participants: chat.participants, myUserId: myUserId);
      if (recipient == null || !mounted) return;
    }
    if (!mounted) return;
    showSendPaymentSheet(
      context,
      ref,
      chatId: widget.chatId,
      prefillAccount: recipient?.user.phoneNumber,
      recipientUserId: recipient?.userId,
    );
  }

  Future<void> _clearChat() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear chat',
      message: 'This deletes all messages in this chat for you.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (confirmed && mounted) {
      await ref.read(chatDetailNotifierProvider(widget.chatId).notifier).clearChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatDetailNotifierProvider(widget.chatId));
    final myUserId = ref.watch(currentUserIdProvider);
    ref.watch(sampayPollingProvider(widget.chatId));
    final chat = state.chat;
    final other = chat != null && !chat.isGroup ? chat.otherParticipant(myUserId) : null;
    final hasUnviewedStatus =
        other != null ? ref.watch(hasUnviewedStatusProvider(other.userId)).valueOrNull ?? false : false;
    final isEncrypted = ref.watch(chatIsEncryptedProvider(widget.chatId)).valueOrNull ?? false;

    final isTyping = state.typingUserIds.isNotEmpty;
    final appBarFg = Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: chat == null
            ? const Text('Chat')
            : GestureDetector(
                onTap: chat.isGroup
                    ? () => context.pushNamed(RouteNames.groupInfo, pathParameters: {'chatId': widget.chatId})
                    : null,
                child: Row(
                children: [
                  Container(
                    padding: hasUnviewedStatus ? const EdgeInsets.all(2) : EdgeInsets.zero,
                    decoration: hasUnviewedStatus
                        ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.primary, width: 2))
                        : null,
                    child: AppAvatar(
                      photoUrl: chat.avatarUrl(myUserId),
                      initials: chat.isGroup
                          ? chat.title(myUserId).substring(0, 1).toUpperCase()
                          : (other?.user.initials ?? '?'),
                      size: 38,
                      showOnlineDot: !chat.isGroup,
                      isOnline: other?.user.isOnlineNow ?? false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isEncrypted) ...[
                              Icon(Icons.lock_outline, size: 13, color: appBarFg.withValues(alpha: 0.85)),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                chat.title(myUserId),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: appBarFg),
                              ),
                            ),
                          ],
                        ),
                        if (isTyping)
                          Text('typing…', style: TextStyle(color: appBarFg, fontSize: 12))
                        else if (!chat.isGroup)
                          Text(
                            AppDateUtils.lastSeen(other?.user.lastSeenAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: appBarFg.withValues(alpha: 0.8)),
                          ),
                      ],
                    ),
                  ),
                ],
                ),
              ),
        actions: [
          if (chat != null && (chat.isGroup || other != null)) ...[
            IconButton(
              icon: const Icon(Icons.call_outlined),
              onPressed: () => context.pushNamed(
                RouteNames.outgoingCall,
                extra: chat.isGroup
                    ? {'chatId': chat.id, 'video': false}
                    : {'receiverId': other!.userId, 'video': false},
              ),
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined),
              onPressed: () => context.pushNamed(
                RouteNames.outgoingCall,
                extra: chat.isGroup
                    ? {'chatId': chat.id, 'video': true}
                    : {'receiverId': other!.userId, 'video': true},
              ),
            ),
          ],
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'clear') _clearChat();
              if (value == 'send_payment') {
                _openSendPayment(state, myUserId, other);
              }
              if (value == 'block' && other != null) {
                await ref.read(profileRepositoryProvider).block(other.userId);
                if (mounted) ref.invalidate(chatDetailNotifierProvider(widget.chatId));
              }
              if (value == 'unblock' && other != null) {
                await ref.read(profileRepositoryProvider).unblock(other.userId);
                if (mounted) ref.invalidate(chatDetailNotifierProvider(widget.chatId));
              }
            },
            itemBuilder: (context) => [
              if (chat != null)
                const PopupMenuItem(value: 'send_payment', child: Text('Send payment')),
              if (chat != null && !chat.isGroup && !chat.blockedByMe)
                const PopupMenuItem(value: 'block', child: Text('Block')),
              if (chat != null && !chat.isGroup && chat.blockedByMe)
                const PopupMenuItem(value: 'unblock', child: Text('Unblock')),
              const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.chatBackgroundDark
                  : AppColors.chatBackgroundLight,
              child: _buildMessageList(state, myUserId),
            ),
          ),
          MessageComposer(
            enabled: state.canSend,
            onChanged: (text) =>
                ref.read(chatDetailNotifierProvider(widget.chatId).notifier).onComposerTextChanged(text),
            onSend: _send,
            onAttach: _pickAttachment,
            onVoiceNote: _sendVoiceNote,
            onSendSticker: _sendSticker,
            onSendPayment: chat != null ? () => _openSendPayment(state, myUserId, other) : null,
            replyPreview: _replyingTo != null
                ? QuotedMessageWidget(
                    message: _replyingTo!,
                    senderLabel: _replyingTo!.isMine(myUserId) ? 'You' : _replyingTo!.sender?.displayName,
                    onClose: () => setState(() => _replyingTo = null),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatDetailState state, String myUserId) {
    if (state.isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.messages.isEmpty) {
      return ErrorStateWidget(
        message: state.error!,
        onRetry: () => ref.invalidate(chatDetailNotifierProvider(widget.chatId)),
      );
    }
    if (state.messages.isEmpty) {
      return Center(
        child: Text('Say hi 👋', style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    final items = <_ListItem>[];
    DateTime? lastDate;
    for (final message in state.messages) {
      if (lastDate == null || !AppDateUtils.isSameDay(lastDate, message.createdAt)) {
        items.add(_ListItem.date(message.createdAt));
        lastDate = message.createdAt;
      }
      items.add(_ListItem.message(message));
    }

    final reversedItems = items.reversed.toList();

    return ListView.builder(
      reverse: true,
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: reversedItems.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.isLoadingMore && index == reversedItems.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final item = reversedItems[index];
        if (item.date != null) return DateSeparator(date: item.date!);
        final message = item.message!;
        final isMine = message.isMine(myUserId);
        return MessageBubble(
          message: message,
          isMine: isMine,
          myUserId: myUserId,
          senderName: (state.chat?.isGroup ?? false) && !isMine ? message.sender?.displayName : null,
          onRetry: message.sendStatus == SendStatus.failed
              ? () => ref.read(chatDetailNotifierProvider(widget.chatId).notifier).retry(message)
              : null,
          onLongPress: message.sendStatus == SendStatus.sending
              ? null
              : () => _showMessageActions(message, isMine),
        );
      },
    );
  }
}

class _ListItem {
  _ListItem.date(this.date) : message = null;
  _ListItem.message(this.message) : date = null;

  final DateTime? date;
  final ChatMessage? message;
}
