import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../models/message.dart';
import '../../../../models/sampay_account.dart';
import '../../application/sampay_status_provider.dart';

/// Renders as its own standalone card — see MessageBubble.build(), which
/// bypasses the generic text/media bubble chrome for payment_request
/// messages and gives this widget full control of background/shadow/footer.
class PaymentRequestBubble extends ConsumerWidget {
  const PaymentRequestBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.chatId,
  });

  final ChatMessage message;
  final bool isMine;
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final meta = message.metadata;
    final amount = meta['amount'];
    final purpose = meta['purpose']?.toString() ?? '';
    final recipientAccount = meta['recipient_account']?.toString();
    final reference = meta['reference']?.toString() ?? meta['transaction_reference']?.toString();
    final rawStatus = meta['status']?.toString() ?? '';
    // Sampay reports statuses (e.g. "completed") beyond what
    // SampayRequestStatus models — show the raw backend value verbatim
    // rather than mapping through the (incomplete) friendly label.
    final status = sampayStatusFromString(rawStatus);
    final statusLabel = rawStatus.toUpperCase();

    final statusColor = switch (rawStatus.toLowerCase()) {
      'approved' || 'completed' => AppColors.online,
      'rejected' || 'failed' => scheme.error,
      _ => scheme.primary,
    };

    final cardColor = scheme.surfaceContainerLow;
    final onCardColor = isMine ? scheme.onPrimary : scheme.onSurface;
    final mutedColor = isMine ? scheme.onPrimary.withValues(alpha: 0.8) : scheme.onSurfaceVariant;
    final iconBg = isMine ? Colors.white.withValues(alpha: 0.22) : statusColor.withValues(alpha: 0.15);
    final iconColor = isMine ? Colors.white : statusColor;
    final chipBg = isMine ? Colors.white.withValues(alpha: 0.18) : scheme.surfaceContainerLow;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: isMine
            ? const LinearGradient(
                colors: AppColors.sentBubbleGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isMine ? null : cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isMine
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.account_balance_wallet_rounded, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'ZMW ${amount ?? ''}',
                style: textTheme.titleMedium?.copyWith(color: onCardColor),
              ),
            ],
          ),
          if (purpose.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(purpose, style: textTheme.bodySmall?.copyWith(color: mutedColor)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(label: statusLabel, backgroundColor: statusColor, foregroundColor: Colors.white),
              if (recipientAccount != null && recipientAccount.isNotEmpty)
                _Chip(label: recipientAccount, backgroundColor: chipBg, foregroundColor: onCardColor),
            ],
          ),
          if (reference != null && reference.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Ref: $reference', style: textTheme.bodySmall?.copyWith(color: mutedColor, fontSize: 11)),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                AppDateUtils.messageTime(message.createdAt),
                style: textTheme.bodySmall?.copyWith(color: mutedColor, fontSize: 10.5),
              ),
              if (isMine) ...[
                const SizedBox(width: 4),
                Icon(
                  message.isReadByRecipient ? Icons.done_all_rounded : Icons.done_rounded,
                  size: 14,
                  color: message.isReadByRecipient ? AppColors.tickRead : Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
          if (!isMine && status == SampayRequestStatus.pendingApproval) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref.read(sampayRepositoryProvider).reject(chatId, message.id),
                    style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref.read(sampayRepositoryProvider).approve(chatId, message.id),
                    style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.backgroundColor, required this.foregroundColor});

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: foregroundColor, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
