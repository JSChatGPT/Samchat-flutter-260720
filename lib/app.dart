import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/crypto/e2ee_realtime_listener.dart';
import 'core/native/app_intent_channel.dart';
import 'core/providers/core_providers.dart';
import 'core/push/push_service.dart';
import 'core/router/app_router.dart';
import 'core/router/route_names.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';
import 'features/auth/application/auth_notifier.dart';
import 'features/auth/application/auth_state.dart';
import 'features/calls/application/call_notifier.dart';
import 'features/calls/application/incoming_call_listener.dart';
import 'features/chats/application/inbox_notifier.dart';
import 'features/email/application/email_notifier.dart';
import 'features/settings/application/app_lock_gate.dart';
import 'features/settings/application/theme_mode_notifier.dart';
import 'features/settings/presentation/widgets/app_lock_gate.dart';
import 'features/sms/application/sms_notifier.dart';
import 'models/call.dart';

class SamChatApp extends ConsumerStatefulWidget {
  const SamChatApp({super.key});

  @override
  ConsumerState<SamChatApp> createState() => _SamChatAppState();
}

class _SamChatAppState extends ConsumerState<SamChatApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleAppIntent(AppIntent intent, GoRouter router) async {
    switch (intent.type) {
      case AppIntentType.smsThread:
      case AppIntentType.smsCompose:
        final address = intent.address;
        if (address == null || address.isEmpty) return;
        final threadId = await ref.read(smsRepositoryProvider).getOrCreateThreadId(address);
        ref.read(smsInboxNotifierProvider.notifier).markThreadRead(threadId);
        router.pushNamed(RouteNames.smsThread, extra: SmsThreadArgs(threadId: threadId, address: address));
      case AppIntentType.share:
        router.pushNamed(RouteNames.shareTarget, extra: intent);
      case AppIntentType.openUserChat:
        final userId = intent.userId;
        if (userId == null || userId.isEmpty) return;
        final chat = await ref.read(chatsRepositoryProvider).createOrGetDirectChat(userId);
        router.pushNamed(RouteNames.chatDetail, pathParameters: {'chatId': chat.id});
      case AppIntentType.answerCall:
        // The incoming-call notification's full-screen intent/Answer action
        // (native Telecom integration — see the samchat_telecom plugin)
        // launched us straight into answering, the same way tapping
        // WhatsApp's lock-screen Answer button does — not just opening the
        // ringing screen for a second confirmation tap.
        final callId = intent.callId;
        if (callId == null || callId.isEmpty) return;
        final callService = ref.read(callServiceProvider);
        if (!callService.alreadyHandling(callId)) {
          // A cold start (app was fully killed) means CallService has never
          // heard of this call via the realtime socket — synthesize just
          // enough of a CallRecord from the notification's own extras
          // (the same fields the FCM push carried) instead of an extra
          // round trip to fetch it.
          final call = CallRecord.fromJson({
            'id': callId,
            'caller_id': intent.callerId ?? '',
            'caller': {
              'id': intent.callerId ?? '',
              'first_name': intent.callerName ?? 'Someone',
              'photo_url': intent.callerPhoto,
            },
            'receiver_id': ref.read(currentUserIdProvider),
            'call_type': (intent.isVideo ?? false) ? 'video' : 'audio',
            'chat_id': intent.chatId,
          });
          callService.registerIncoming(call, intent.isVideo ?? false);
        }
        ref.read(incomingCallProvider.notifier).state = callService.currentCall;
        await callService.acceptCall();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final heartbeat = ref.read(heartbeatServiceProvider);
    final lockGate = ref.read(appLockGateProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      lockGate.onResumed();
      if (ref.read(authNotifierProvider).status == AuthStatus.authenticated) {
        heartbeat.onResumed();
      }
    } else if (state == AppLifecycleState.paused) {
      lockGate.onPaused();
      heartbeat.onPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    // App-lifetime side effect: keeps `user.{myId}` subscribed for IncomingCall.
    ref.watch(incomingCallListenerProvider);
    // App-lifetime side effect: reseals chat keys to other devices (e.g. a
    // new phone or web login) that ask for them — see e2ee_realtime_listener.
    ref.watch(e2eeRealtimeListenerProvider);
    // App-lifetime side effect: keeps email tab/account badges live when the
    // backend's periodic mailbox sync finds new mail while foregrounded.
    ref.watch(emailRealtimeListenerProvider);

    ref.listen(incomingCallProvider, (previous, next) {
      if (next != null) {
        router.pushNamed(RouteNames.incomingCall);
      }
    });

    // Notification-tap navigation (message / incoming_call) — see
    // core/push/push_service.dart.
    ref.listen(pushNavigationStreamProvider, (previous, next) {
      final target = next.valueOrNull;
      if (target == null) return;
      if (target.type == PushNavigationType.chat && target.chatId != null) {
        ref.read(inboxNotifierProvider.notifier).markChatRead(target.chatId!);
        router.pushNamed(RouteNames.chatDetail, pathParameters: {'chatId': target.chatId!});
      } else if (target.type == PushNavigationType.incomingCall) {
        router.pushNamed(RouteNames.incomingCall);
      } else if (target.type == PushNavigationType.email) {
        router.goNamed(RouteNames.emailAccounts);
      }
    });

    // SMS notification tap / `sms:` compose link / share-sheet SEND — see
    // core/native/app_intent_service.dart.
    ref.listen(appIntentStreamProvider, (previous, next) {
      final intent = next.valueOrNull;
      if (intent == null) return;
      _handleAppIntent(intent, router);
    });

    // First heartbeat as soon as we become authenticated (not just on resume).
    ref.listen(authNotifierProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated && next.status == AuthStatus.authenticated) {
        ref.read(heartbeatServiceProvider).onResumed();
        // Best-effort: generates this device's E2EE keypair on first run (or
        // loads it) and makes sure the backend has the current public key.
        // Never blocks login — chats just stay unencrypted until this lands.
        ref.read(e2eeServiceProvider).ensureDeviceRegistered().catchError((_) {});
      } else if (next.status == AuthStatus.unauthenticated) {
        ref.read(heartbeatServiceProvider).onPaused();
      }
    });

    return MaterialApp.router(
      title: 'Samchat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeNotifierProvider),
      routerConfig: router,
      builder: (context, child) =>
          AppLockGateOverlay(child: OfflineBanner(child: child ?? const SizedBox.shrink())),
    );
  }
}
