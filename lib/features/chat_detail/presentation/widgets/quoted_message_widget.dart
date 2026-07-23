import 'package:flutter/material.dart';

import '../../../../models/message.dart';

/// Compact preview of a quoted/replied-to message, used both above the
/// composer (while composing a reply) and inline inside a bubble.
class QuotedMessageWidget extends StatelessWidget {
  const QuotedMessageWidget({
    super.key,
    required this.message,
    this.senderLabel,
    this.onClose,
    this.onTap,
    this.dense = false,
  });

  final ChatMessage message;
  final String? senderLabel;
  final VoidCallback? onClose;

  /// Set only for the inline preview inside a bubble (never the composer's
  /// reply-preview above it) — jumps to and briefly highlights the original
  /// message, WhatsApp-style. See ChatDetailScreen._scrollToMessage.
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderLabel ?? 'Message',
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                Text(
                  message.previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: content),
    );
  }
}
