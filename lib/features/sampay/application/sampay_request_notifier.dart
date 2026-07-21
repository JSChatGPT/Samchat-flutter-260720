import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../models/message.dart';
import '../../../models/sampay_account.dart';
import '../../chat_detail/application/chat_detail_notifier.dart';
import 'sampay_status_provider.dart';

/// Polls `POST /chats/{id}/sampay/sync-status` every ~8s (server-rate-limited
/// to 1/7s) while [chatId]'s currently-loaded messages contain at least one
/// non-terminal `payment_request`. Status updates themselves arrive back via
/// the normal `MessageSent` broadcast the chat is already listening to — this
/// provider only decides *whether* to keep polling, it doesn't touch message
/// state directly.
final sampayPollingProvider = Provider.autoDispose.family<void, String>((ref, chatId) {
  Timer? timer;

  void tick() {
    final messages = ref.read(chatDetailNotifierProvider(chatId)).messages;
    final hasPending = messages.any((m) =>
        m.messageType == MessageType.paymentRequest &&
        !sampayStatusFromString(m.metadata['status']?.toString()).isTerminal);
    if (hasPending) {
      ref.read(sampayRepositoryProvider).syncStatus(chatId);
    }
  }

  timer = Timer.periodic(AppConfig.sampaySyncInterval, (_) => tick());
  ref.onDispose(() => timer?.cancel());
});
