import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_notifier.dart';
import '../providers/core_providers.dart';
import '../realtime/realtime_events.dart';

/// App-lifetime side-effect provider: subscribes to `user.{myId}` and reacts
/// to `ChatKeyGrantRequested` by resealing this chat's key to whichever
/// device asked for it (see E2eeService.handleGrantRequest), regardless of
/// whether that chat happens to be open right now — chat_detail_notifier's
/// own `private-chat.{chatId}` subscription is autoDispose'd with the screen,
/// so it's not a reliable place to catch this. Read once (e.g. in `app.dart`)
/// to activate, the same way incomingCallListenerProvider is.
final e2eeRealtimeListenerProvider = Provider<void>((ref) {
  final pusher = ref.watch(pusherServiceProvider);
  final e2ee = ref.watch(e2eeServiceProvider);
  final myUserId = ref.watch(currentUserIdProvider);

  final sub = pusher.events.listen((event) {
    if (event.eventName != RealtimeEventNames.chatKeyGrantRequested) return;
    if (myUserId.isEmpty || event.channelName != RealtimeChannels.user(myUserId)) return;

    final chatId = event.data['chat_id']?.toString();
    if (chatId == null || chatId.isEmpty) return;
    e2ee.handleGrantRequest(chatId);
  });

  ref.onDispose(sub.cancel);
});
