import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../models/chat.dart';

class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.chat,
    required this.myUserId,
    required this.onTap,
    required this.onMute,
    required this.onDelete,
    this.isTyping = false,
  });

  final Chat chat;
  final String myUserId;
  final VoidCallback onTap;
  final VoidCallback onMute;
  final VoidCallback onDelete;

  /// True when the other participant is currently typing — overrides the
  /// last-message preview with "typing…", mirroring the open chat screen.
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final other = chat.otherParticipant(myUserId);
    final title = chat.title(myUserId);
    final lastMessage = chat.lastMessage;
    final isOnline = !chat.isGroup && (other?.user.isOnlineNow ?? false);

    IconData? getPreviewIcon(String text) {
      final t = text.toLowerCase();
      if (t.contains('photo')) return Icons.image;
      if (t.contains('audio')) return Icons.phone;
      if (t.contains('video')) return Icons.videocam;
      return null;
    }

    final previewIcon = lastMessage != null ? getPreviewIcon(lastMessage.previewText) : null;

    // WhatsApp-style "Sender: message" prefix so a group's last message is
    // legible at a glance without opening it — own messages skip the
    // prefix (the tick icon already marks them as "sent by me").
    String previewText = isTyping ? 'typing…' : (lastMessage?.previewText ?? 'No messages yet');
    if (!isTyping && chat.isGroup && lastMessage != null && lastMessage.senderId != myUserId) {
      final senderName = lastMessage.sender?.displayName.split(' ').first;
      if (senderName != null && senderName.isNotEmpty) {
        previewText = '$senderName: $previewText';
      }
    }

    return Slidable(
      key: ValueKey(chat.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => onMute(),
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            icon: chat.isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
            label: chat.isMuted ? 'Unmute' : 'Mute',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: scheme.errorContainer,
            foregroundColor: scheme.onErrorContainer,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: AppAvatar(
          photoUrl: chat.avatarUrl(myUserId),
          initials: chat.isGroup ? title.substring(0, 1).toUpperCase() : (other?.user.initials ?? '?'),
          showOnlineDot: !chat.isGroup,
          isOnline: isOnline,
          isGroup: chat.isGroup,
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium,
        ),
        subtitle: Row(
          children: [
            if (!isTyping && lastMessage != null && lastMessage.senderId == myUserId) ...[
              Icon(
                lastMessage.isReadByRecipient ? Icons.done_all_rounded : Icons.done_rounded,
                size: 16,
                color: lastMessage.isReadByRecipient ? AppColors.tickRead : AppColors.tickDelivered,
              ),
              const SizedBox(width: 4),
            ],
            if (!isTyping && previewIcon != null) ...[
              Icon(previewIcon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                previewText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: isTyping ? scheme.primary : (previewIcon != null ? scheme.onSurfaceVariant : null),
                  fontStyle: isTyping ? FontStyle.italic : null,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lastMessage != null ? AppDateUtils.inboxTimestamp(lastMessage.createdAt) : '',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            if (chat.isMuted)
              Icon(Icons.notifications_off_outlined, size: 16, color: scheme.onSurfaceVariant)
            else if (chat.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                  style: TextStyle(color: scheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
