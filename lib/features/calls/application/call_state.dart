import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../models/call.dart';
import '../../../models/user.dart';

enum CallPhase { idle, outgoingRinging, incomingRinging, connecting, active, ended, failed }

class CallParticipantState {
  const CallParticipantState({
    required this.userId,
    this.user,
    this.name,
    this.photoUrl,
    this.renderer,
    this.connected = false,
  });

  final String userId;
  final AppUser? user;

  /// Name/photo learned from the WebRTC signaling payload (`client-user-joined`
  /// / offer `senderName`+`senderPhoto`) — the only identity info available
  /// for a group-call participant who isn't the 1:1 [CallRecord.counterpart].
  final String? name;
  final String? photoUrl;
  final RTCVideoRenderer? renderer;
  final bool connected;

  String get displayName => user?.displayName ?? name ?? 'Participant';
  String? get displayPhoto => user?.photoUrl ?? photoUrl;

  CallParticipantState copyWith({
    String? name,
    String? photoUrl,
    RTCVideoRenderer? renderer,
    bool? connected,
  }) {
    return CallParticipantState(
      userId: userId,
      user: user,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      renderer: renderer ?? this.renderer,
      connected: connected ?? this.connected,
    );
  }
}

class CallSessionState {
  const CallSessionState({
    this.phase = CallPhase.idle,
    this.call,
    this.isVideo = false,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isSpeakerOn = false,
    this.localRenderer,
    this.participants = const {},
    this.error,
  });

  final CallPhase phase;
  final CallRecord? call;
  final bool isVideo;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final RTCVideoRenderer? localRenderer;
  final Map<String, CallParticipantState> participants;
  final String? error;

  bool get isActive => phase == CallPhase.active || phase == CallPhase.connecting;

  CallSessionState copyWith({
    CallPhase? phase,
    CallRecord? call,
    bool? isVideo,
    bool? isMuted,
    bool? isCameraOff,
    bool? isSpeakerOn,
    RTCVideoRenderer? localRenderer,
    Map<String, CallParticipantState>? participants,
    String? error,
  }) {
    return CallSessionState(
      phase: phase ?? this.phase,
      call: call ?? this.call,
      isVideo: isVideo ?? this.isVideo,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      localRenderer: localRenderer ?? this.localRenderer,
      participants: participants ?? this.participants,
      error: error,
    );
  }
}
