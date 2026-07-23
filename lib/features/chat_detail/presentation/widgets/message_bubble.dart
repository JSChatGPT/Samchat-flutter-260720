import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../models/message.dart';
import '../../../sampay/presentation/widgets/payment_request_bubble.dart';
import '../screens/full_screen_image_viewer.dart';
import '../screens/video_player_screen.dart';
import 'audio_message_player.dart';
import 'quoted_message_widget.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.myUserId,
    this.senderName,
    this.onRetry,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool isMine;
  final String myUserId;
  final String? senderName;
  final VoidCallback? onRetry;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    // Payment requests render as their own standalone card (own background,
    // shadow, and timestamp) rather than nesting inside the generic bubble
    // chrome below — they need more visual weight than a text/media bubble.
    if (message.messageType == MessageType.paymentRequest) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: PaymentRequestBubble(message: message, isMine: isMine, chatId: message.chatId),
        ),
      );
    }

    // Stickers render as an oversized, bubble-less emoji — same idea as
    // WhatsApp's own auto-enlarge treatment for a lone-emoji message.
    if (message.messageType == MessageType.sticker) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: isMine ? 64 : 12, right: isMine ? 12 : 64, top: 2, bottom: 2),
          child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message.content ?? '🎉', style: const TextStyle(fontSize: 72)),
              if (message.reactions.isNotEmpty) _ReactionPills(reactions: message.reactions, myUserId: myUserId),
            ],
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = isMine ? scheme.onPrimary : scheme.onSurface;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: Radius.circular(isMine ? 12 : 0),
      bottomRight: Radius.circular(isMine ? 0 : 12),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: EdgeInsets.only(left: isMine ? 64 : 12, right: isMine ? 12 : 64, top: 2, bottom: 2),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            gradient: isMine
                ? const LinearGradient(
                    colors: AppColors.sentBubbleGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isMine ? null : scheme.surfaceContainerLow,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (senderName != null) ...[
                Text(
                  senderName!,
                  style: textTheme.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
              ],
              if (message.quotedMessage != null) ...[
                QuotedMessageWidget(
                  message: message.quotedMessage!,
                  dense: true,
                  senderLabel: message.quotedMessage!.isMine(myUserId)
                      ? 'You'
                      : message.quotedMessage!.sender?.displayName,
                ),
                const SizedBox(height: 6),
              ],
              _buildContent(context, textColor),
              if (message.reactions.isNotEmpty) ...[
                const SizedBox(height: 4),
                _ReactionPills(reactions: message.reactions, myUserId: myUserId),
              ],
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppDateUtils.messageTime(message.createdAt),
                    style: textTheme.bodySmall?.copyWith(fontSize: 10.5),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    _StatusIcon(message: message, onRetry: onRetry),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    final textTheme = Theme.of(context).textTheme;
    switch (message.messageType) {
      case MessageType.text:
        return Text(message.content ?? '', style: textTheme.bodyMedium?.copyWith(color: textColor));
      case MessageType.image:
        return _ImageContent(message: message, caption: message.content, textColor: textColor);
      case MessageType.video:
        return _VideoContent(message: message, caption: message.content, textColor: textColor);
      case MessageType.audio:
        return AudioMessagePlayer(
          url: message.mediaUrl ?? '',
          iconColor: textColor,
          trackColor: textColor.withValues(alpha: 0.3),
        );
      case MessageType.file:
        return _FileContent(message: message, textColor: textColor);
      case MessageType.paymentRequest:
      case MessageType.sticker:
        // Both handled by early returns in build() above.
        return const SizedBox.shrink();
      case MessageType.callLog:
        return _CallLogContent(message: message, isMine: isMine, textColor: textColor);
      case MessageType.unknown:
        return Text(message.previewText, style: textTheme.bodyMedium?.copyWith(color: textColor));
    }
  }
}

class _CallLogContent extends StatelessWidget {
  const _CallLogContent({required this.message, required this.isMine, required this.textColor});

  final ChatMessage message;
  final bool isMine;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMissed = message.metadata['status']?.toString() == 'missed';
    final isVideo = message.metadata['call_type']?.toString() == 'video';
    final iconColor = isMissed ? AppColors.error : (isMine ? scheme.onPrimary : scheme.primary);
    final text = isMissed ? 'Missed call' : 'Call ended';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(isVideo ? Icons.videocam_rounded : Icons.phone_rounded, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.message, required this.caption, required this.textColor});

  final ChatMessage message;
  final String? caption;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: url == null
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: url, heroTag: message.id)),
                  ),
          child: Hero(
            tag: message.id,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: url != null
                  ? CachedNetworkImage(
                      imageUrl: url,
                      width: 220,
                      fit: BoxFit.cover,
                      placeholder: (context, _) => Container(width: 220, height: 160, color: Colors.black12),
                      errorWidget: (context, _, error) => Container(
                        width: 220,
                        height: 160,
                        color: Colors.black12,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    )
                  : Container(width: 220, height: 160, color: Colors.black12),
            ),
          ),
        ),
        if (caption != null && caption!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(caption!, style: TextStyle(color: textColor)),
        ],
      ],
    );
  }
}

class _VideoContent extends StatelessWidget {
  const _VideoContent({required this.message, required this.caption, required this.textColor});

  final ChatMessage message;
  final String? caption;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: url == null
              ? null
              : () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoUrl: url))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 220,
              height: 160,
              color: Colors.black87,
              child: const Icon(Icons.play_circle_fill, color: Colors.white70, size: 40),
            ),
          ),
        ),
        if (caption != null && caption!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(caption!, style: TextStyle(color: textColor)),
        ],
      ],
    );
  }
}

class _FileContent extends StatelessWidget {
  const _FileContent({required this.message, required this.textColor});

  final ChatMessage message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.insert_drive_file_outlined, color: textColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message.fileName ?? 'File',
            style: TextStyle(color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (message.sendStatus) {
      case SendStatus.sending:
        return const SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        );
      case SendStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: Icon(Icons.error_outline, size: 14, color: Theme.of(context).colorScheme.error),
        );
      case SendStatus.sent:
        return Icon(
          message.isReadByRecipient ? Icons.done_all_rounded : Icons.done_rounded,
          size: 14,
          color: message.isReadByRecipient ? AppColors.tickRead : AppColors.tickDelivered,
        );
      case SendStatus.read:
        return Icon(Icons.done_all_rounded, size: 14, color: AppColors.tickRead);
    }
  }
}

/// Reactions grouped by emoji with a count — the current user's own
/// reaction gets a tinted border, mirroring the highlight WhatsApp gives
/// your own reaction pill.
class _ReactionPills extends StatelessWidget {
  const _ReactionPills({required this.reactions, required this.myUserId});

  final List<MessageReaction> reactions;
  final String myUserId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final counts = <String, int>{};
    final mine = <String>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
      if (r.userId == myUserId) mine.add(r.emoji);
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: counts.entries.map((entry) {
        final isMine = mine.contains(entry.key);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isMine ? scheme.primary : scheme.outlineVariant, width: isMine ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.key, style: const TextStyle(fontSize: 13)),
              if (entry.value > 1) ...[
                const SizedBox(width: 3),
                Text('${entry.value}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
