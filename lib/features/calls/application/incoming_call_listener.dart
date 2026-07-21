import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/realtime/realtime_events.dart';
import '../../../models/call.dart';
import '../../auth/application/auth_notifier.dart';
import 'call_notifier.dart';

/// The call currently ringing in (if any) — a thin piece of app-root state
/// that a widget near [SamChatApp]'s root watches to push the full-screen
/// incoming-call route. Kept separate from [CallNotifier]'s richer session
/// state so the listener itself has nothing to tear down between calls.
final incomingCallProvider = StateProvider<CallRecord?>((ref) => null);

/// App-lifetime side-effect provider: subscribes to `user.{myId}` and feeds
/// `IncomingCall` events into [incomingCallProvider] + primes [CallService]
/// with the call's details. Read once (e.g. in `app.dart`) to activate.
final incomingCallListenerProvider = Provider<void>((ref) {
  final pusher = ref.watch(pusherServiceProvider);
  final callService = ref.watch(callServiceProvider);
  final myUserId = ref.watch(currentUserIdProvider);

  final sub = pusher.events.listen((event) {
    if (event.eventName != RealtimeEventNames.incomingCall) return;
    if (myUserId.isEmpty || event.channelName != RealtimeChannels.user(myUserId)) return;

    // `IncomingCall` has no broadcastWith(), so Laravel wraps the model under
    // a top-level `call` key (the web client reads `e.call`). Reading the id
    // off `event.data` directly would always be null and the phone would never
    // ring.
    final callJson = event.data['call'];
    if (callJson is! Map) return;
    final callMap = Map<String, dynamic>.from(callJson);
    final callId = callMap['id']?.toString();
    if (callId == null || callService.alreadyHandling(callId)) {
      return;
    }

    final call = CallRecord.fromJson(callMap);
    final isVideo = call.callType.name == 'video';
    callService.registerIncoming(call, isVideo);
    ref.read(incomingCallProvider.notifier).state = call;
  });

  ref.onDispose(sub.cancel);
});
