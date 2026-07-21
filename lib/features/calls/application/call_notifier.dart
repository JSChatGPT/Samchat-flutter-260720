import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/providers/core_providers.dart';
import '../../../models/call.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/calls_repository.dart';
import 'call_service.dart';
import 'call_state.dart';

final callsRepositoryProvider = Provider<CallsRepository>((ref) {
  return CallsRepository(ref.watch(dioProvider));
});

/// Watched by [CallHistoryScreen] instead of a one-shot `initState` fetch —
/// the call-history tab lives inside a [StatefulShellRoute.indexedStack],
/// which keeps it alive (so `initState` never re-runs) when the user
/// switches away and back. Watching this provider lets [CallNotifier]
/// invalidate it as soon as a call ends, so the list updates immediately
/// instead of only after a manual pull-to-refresh.
final callHistoryProvider = FutureProvider<List<CallRecord>>((ref) {
  return ref.watch(callsRepositoryProvider).history();
});

/// App-lifetime: one CallService for the whole session so an incoming call
/// can be answered regardless of which screen is currently showing.
final callServiceProvider = Provider<CallService>((ref) {
  final service = CallService(
    repository: ref.watch(callsRepositoryProvider),
    pusher: ref.watch(pusherServiceProvider),
    myUserId: ref.watch(currentUserIdProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final callNotifierProvider = StateNotifierProvider<CallNotifier, CallSessionState>((ref) {
  return CallNotifier(ref, ref.watch(callServiceProvider));
});

class CallNotifier extends StateNotifier<CallSessionState> {
  CallNotifier(this.ref, this.service) : super(const CallSessionState()) {
    _sub = service.events.listen(_onServiceEvent);
  }

  final Ref ref;
  final CallService service;
  StreamSubscription? _sub;

  Future<void> startOutgoingCall({required String receiverId, required bool video}) async {
    state = state.copyWith(phase: CallPhase.outgoingRinging, isVideo: video);
    await service.startOutgoingCall(receiverId: receiverId, video: video);
    await _attachLocalRenderer();
  }

  Future<void> startOutgoingGroupCall({required String chatId, required bool video}) async {
    state = state.copyWith(phase: CallPhase.outgoingRinging, isVideo: video);
    await service.startOutgoingGroupCall(chatId: chatId, video: video);
    await _attachLocalRenderer();
  }

  Future<void> prepareIncoming() async {
    state = state.copyWith(phase: CallPhase.incomingRinging, call: service.currentCall, isVideo: service.isVideo);
  }

  Future<void> accept() async {
    state = state.copyWith(phase: CallPhase.connecting);
    await service.acceptCall();
    await _attachLocalRenderer();
  }

  Future<void> decline() => service.declineCall();

  Future<void> end() => service.endCall();

  void toggleMute() {
    service.toggleMute();
    state = state.copyWith(isMuted: !state.isMuted);
  }

  void toggleCamera() {
    service.toggleCamera();
    state = state.copyWith(isCameraOff: !state.isCameraOff);
  }

  void switchCamera() => service.switchCamera();

  void toggleSpeaker() {
    state = state.copyWith(isSpeakerOn: !state.isSpeakerOn);
    Helper.setSpeakerphoneOn(state.isSpeakerOn);
  }

  Future<void> _attachLocalRenderer() async {
    final stream = service.localStream;
    if (stream == null) return;
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    state = state.copyWith(localRenderer: renderer);
  }

  void _removeParticipant(String peerId) {
    final participants = {...state.participants};
    participants.remove(peerId)?.renderer?.dispose();
    state = state.copyWith(participants: participants);
  }

  Future<void> _attachRemoteRenderer(String peerId, {String? name, String? photoUrl}) async {
    final stream = service.remoteStreams[peerId];
    if (stream == null) return;
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    final participants = {...state.participants};
    participants[peerId] = (participants[peerId] ?? CallParticipantState(userId: peerId))
        .copyWith(renderer: renderer, connected: true, name: name, photoUrl: photoUrl);
    state = state.copyWith(participants: participants, phase: CallPhase.active);
  }

  void _onServiceEvent(CallServiceEvent event) {
    switch (event.type) {
      case CallServiceEventType.ringingOutgoing:
        state = state.copyWith(phase: CallPhase.outgoingRinging, call: event.call);
        break;
      case CallServiceEventType.ringingIncoming:
        state = state.copyWith(phase: CallPhase.incomingRinging, call: event.call);
        break;
      case CallServiceEventType.answered:
        state = state.copyWith(phase: CallPhase.connecting, call: event.call);
        break;
      case CallServiceEventType.connecting:
        state = state.copyWith(phase: CallPhase.connecting);
        break;
      case CallServiceEventType.peerConnected:
        if (event.peerId != null) {
          _attachRemoteRenderer(event.peerId!, name: event.peerName, photoUrl: event.peerPhoto);
        }
        break;
      case CallServiceEventType.peerLeft:
        if (event.peerId != null) _removeParticipant(event.peerId!);
        break;
      case CallServiceEventType.ended:
      case CallServiceEventType.declined:
        _resetAfterCall();
        break;
      case CallServiceEventType.failed:
        state = state.copyWith(phase: CallPhase.failed, error: event.message);
        ref.invalidate(callHistoryProvider);
        break;
    }
  }

  void _resetAfterCall() {
    disposeRenderers();
    state = const CallSessionState(phase: CallPhase.ended);
    ref.invalidate(callHistoryProvider);
  }

  void disposeRenderers() {
    state.localRenderer?.dispose();
    for (final p in state.participants.values) {
      p.renderer?.dispose();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    disposeRenderers();
    super.dispose();
  }
}
