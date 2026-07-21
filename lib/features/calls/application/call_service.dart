import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:samchat_telecom/samchat_telecom.dart';

import '../../../core/config/app_config.dart';
import '../../../core/realtime/pusher_service.dart';
import '../../../core/realtime/realtime_events.dart';
import '../../../models/call.dart';
import '../data/calls_repository.dart';

enum CallServiceEventType {
  ringingOutgoing,
  ringingIncoming,
  answered,
  connecting,
  peerConnected,
  peerLeft,
  ended,
  declined,
  failed,
}

class CallServiceEvent {
  const CallServiceEvent(this.type, {this.call, this.peerId, this.message, this.peerName, this.peerPhoto});

  final CallServiceEventType type;
  final CallRecord? call;
  final String? peerId;
  final String? message;

  /// Only set on [CallServiceEventType.peerConnected] — the display name/photo
  /// learned from that peer's signaling payload (see _rememberPeerIdentity),
  /// needed for group calls where the peer isn't the 1:1 counterpart.
  final String? peerName;
  final String? peerPhoto;
}

/// Thrown when the microphone (or camera, for video) permission is not granted
/// at call time, so the UI can show a clear "permission needed" failure instead
/// of hanging on "Connecting".
class CallPermissionException implements Exception {
  CallPermissionException(this.denied);
  final List<String> denied;
  bool get needsCamera => denied.any((p) => p.contains('camera'));

  @override
  String toString() =>
      needsCamera ? 'Camera & microphone permission needed' : 'Microphone permission needed';
}

/// ICE servers for every peer connection. Always includes public STUN;
/// appends a TURN relay when [AppConfig.turnUrl] is set (see AppConfig for why
/// TURN is needed when a direct path is blocked). Built per-call so a config
/// change takes effect on the next call without a hot restart.
Map<String, dynamic> _buildIceServers() {
  final servers = <Map<String, dynamic>>[
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];
  if (AppConfig.turnUrl.isNotEmpty) {
    final urls = AppConfig.turnUrl.split(',').map((u) => u.trim()).where((u) => u.isNotEmpty).toList();
    servers.add({
      'urls': urls.length == 1 ? urls.first : urls,
      if (AppConfig.turnUsername.isNotEmpty) 'username': AppConfig.turnUsername,
      if (AppConfig.turnCredential.isNotEmpty) 'credential': AppConfig.turnCredential,
    });
  }
  return {'iceServers': servers};
}

/// Orchestrates WebRTC mesh calls (1:1 and group) on top of the shared
/// [PusherService] for signaling relay. See API_DOCUMENTATION.md §7 for the
/// exact REST signaling flow this mirrors. Not a widget/provider itself —
/// held by `call_notifier.dart` and driven through its public methods.
class CallService {
  CallService({required this.repository, required this.pusher, required this.myUserId}) {
    _frameSub = pusher.events.listen(_onRealtimeEvent);
  }

  final CallsRepository repository;
  final PusherService pusher;
  final String myUserId;

  final _eventsController = StreamController<CallServiceEvent>.broadcast();
  Stream<CallServiceEvent> get events => _eventsController.stream;

  StreamSubscription? _frameSub;
  Timer? _ringTimeout;

  String? currentCallId;
  CallRecord? currentCall;
  bool isVideo = false;
  bool isCaller = false;
  final Set<String> _handledCallIds = {}; // de-dupe socket-vs-push double triggers

  MediaStream? localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};
  final Set<String> _remoteDescriptionSet = {};
  final Map<String, MediaStream> remoteStreams = {};

  // Learned from signaling payloads (client-user-joined's userName/userPhoto,
  // or an offer/answer/candidate's senderName/senderPhoto) — the only
  // identity info available for a group-call participant who isn't the 1:1
  // CallRecord.counterpart.
  final Map<String, String> _peerNames = {};
  final Map<String, String> _peerPhotos = {};

  Future<MediaStream> _ensureLocalStream() async {
    if (localStream != null) return localStream!;
    await _ensureCallPermissions();
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo ? {'facingMode': 'user'} : false,
    });
    return localStream!;
  }

  /// Request mic (and camera, for video calls) at runtime. On Android 13+ /
  /// iOS these must be granted before `getUserMedia`, otherwise it throws or
  /// hangs — which used to silently wedge the whole call (the accept/answer
  /// REST call is issued *after* the local stream is ready, so a blocked mic
  /// meant the other side never left "Calling" and this side sat on
  /// "Connecting" forever). Throws a [CallPermissionException] if denied so the
  /// caller can surface a clear failure instead of hanging.
  Future<void> _ensureCallPermissions() async {
    final needed = <Permission>[Permission.microphone];
    if (isVideo) needed.add(Permission.camera);
    final results = await needed.request();
    final denied = results.entries
        .where((e) => !e.value.isGranted)
        .map((e) => e.key.toString())
        .toList();
    if (denied.isNotEmpty) {
      throw CallPermissionException(denied);
    }
  }

  // ---- Caller side (1:1 and group) ----

  Future<void> startOutgoingCall({required String receiverId, required bool video}) {
    return _startOutgoing(receiverId: receiverId, video: video);
  }

  /// Starts a group call for every participant of [chatId] — mirrors
  /// startOutgoingCall, just initiating with a chat instead of a single
  /// receiver (see CallController::initiate, which accepts either). The
  /// mesh signaling itself (client-user-joined / offer-to-each-newcomer)
  /// already generalizes to N participants without special-casing.
  Future<void> startOutgoingGroupCall({required String chatId, required bool video}) {
    return _startOutgoing(chatId: chatId, video: video);
  }

  Future<void> _startOutgoing({String? receiverId, String? chatId, required bool video}) async {
    isVideo = video;
    isCaller = true;
    final call = await repository.initiate(
      receiverId: receiverId,
      chatId: chatId,
      type: video ? CallType.video : CallType.audio,
    );
    currentCall = call;
    currentCallId = call.id;
    _handledCallIds.add(call.id);
    await pusher.subscribe(RealtimeChannels.call(call.id));
    try {
      await _ensureLocalStream();
    } catch (e) {
      _eventsController.add(CallServiceEvent(CallServiceEventType.failed, message: e.toString()));
      await endCall();
      return;
    }
    _eventsController.add(CallServiceEvent(CallServiceEventType.ringingOutgoing, call: call));
    _startRingTimeout();
  }

  // ---- Callee side (1:1 and group entry) ----

  bool alreadyHandling(String callId) => _handledCallIds.contains(callId);

  void registerIncoming(CallRecord call, bool video) {
    isVideo = video;
    isCaller = false;
    currentCall = call;
    currentCallId = call.id;
    _handledCallIds.add(call.id);
    _startRingTimeout();
  }

  Future<void> acceptCall() async {
    final callId = currentCallId;
    if (callId == null) return;
    _ringTimeout?.cancel();
    await pusher.subscribe(RealtimeChannels.call(callId));
    try {
      await _ensureLocalStream();
    } catch (e) {
      // Media (mic/camera) could not be acquired — decline so the caller stops
      // ringing rather than leaving both sides wedged on "Calling"/"Connecting".
      _eventsController.add(CallServiceEvent(CallServiceEventType.failed, message: e.toString()));
      await declineCall();
      return;
    }
    await repository.accept(callId);
    _eventsController.add(CallServiceEvent(CallServiceEventType.connecting, call: currentCall));
    // Announce ourselves on the call channel. Every peer already in the call
    // (the caller in a 1:1, plus any other participants in a group) responds by
    // creating and sending us an offer — this mirrors the web mesh model. As
    // the joiner we only ever answer, never offer, which avoids offer/answer
    // glare. This is sent for 1:1 *and* group calls; previously 1:1 relied on
    // the caller offering off CallAnswered, which deadlocked against a web
    // caller (web only offers in response to this join signal).
    await repository.join(callId);
  }

  Future<void> declineCall() async {
    final callId = currentCallId;
    _ringTimeout?.cancel();
    if (callId != null) {
      try {
        await repository.decline(callId);
      } catch (_) {}
      // Keeps Android's Telecom framework in sync when the decline was
      // triggered from in here (e.g. the 45s ring-timeout) rather than from
      // the native incoming-call notification itself — a no-op if this
      // call was never handed to Telecom (declined before ringing natively,
      // or Telecom unsupported on this device).
      unawaited(SamchatTelecom.endCall(callId));
    }
    _eventsController.add(const CallServiceEvent(CallServiceEventType.declined));
    await _teardown();
  }

  Future<void> endCall() async {
    final callId = currentCallId;
    if (callId != null) {
      try {
        await repository.end(callId);
      } catch (_) {}
      // See declineCall — keeps Telecom's state in sync with the in-app
      // "End" button (or a peer-lost/self-timeout auto-end).
      unawaited(SamchatTelecom.endCall(callId));
    }
    _eventsController.add(const CallServiceEvent(CallServiceEventType.ended));
    await _teardown();
  }

  void _startRingTimeout() {
    _ringTimeout?.cancel();
    _ringTimeout = Timer(const Duration(seconds: 45), () {
      if (isCaller) {
        endCall();
      } else {
        declineCall();
      }
    });
  }

  // ---- Peer connection management ----

  Future<RTCPeerConnection> _getOrCreatePeer(String peerId) async {
    final existing = _peerConnections[peerId];
    if (existing != null) return existing;

    final pc = await createPeerConnection({..._buildIceServers(), 'sdpSemantics': 'unified-plan'});
    final stream = await _ensureLocalStream();
    for (final track in stream.getTracks()) {
      await pc.addTrack(track, stream);
    }

    pc.onIceCandidate = (candidate) {
      final callId = currentCallId;
      if (callId == null || candidate.candidate == null) return;
      repository.sendCandidate(callId, targetId: peerId, candidate: candidate.toMap());
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStreams[peerId] = event.streams.first;
        _eventsController.add(CallServiceEvent(
          CallServiceEventType.peerConnected,
          peerId: peerId,
          peerName: _peerNames[peerId],
          peerPhoto: _peerPhotos[peerId],
        ));
      }
    };

    pc.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _removePeer(peerId);
        if (_peerConnections.isEmpty) {
          // In a 1:1 call this was the only peer, so there's nothing left to
          // stay connected to — end the call rather than leaving the local
          // stream/signaling subscription open with the screen already
          // popped. In a group call this means we're the last one left, so
          // the same "nothing to stay connected to" logic applies.
          _eventsController.add(CallServiceEvent(
            CallServiceEventType.failed,
            peerId: peerId,
            message: 'Connection to peer lost',
          ));
          endCall();
        } else {
          // Other peers are still connected (a group call) — this is just
          // one participant's connection dropping, not the whole call
          // failing, so only remove their tile instead of ending the screen
          // for everyone still on the call.
          _eventsController.add(CallServiceEvent(CallServiceEventType.peerLeft, peerId: peerId));
        }
      }
    };

    _peerConnections[peerId] = pc;
    return pc;
  }

  /// Closes and forgets a single peer's connection (and its pending signaling
  /// state) without touching the rest of the call — used when that peer's ICE
  /// connection fails/drops so its resources don't leak past the failure.
  void _removePeer(String peerId) {
    final pc = _peerConnections.remove(peerId);
    pc?.close();
    _pendingCandidates.remove(peerId);
    _remoteDescriptionSet.remove(peerId);
    remoteStreams.remove(peerId);
    _peerNames.remove(peerId);
    _peerPhotos.remove(peerId);
  }

  Future<void> _initiateOfferTo(String peerId) async {
    final callId = currentCallId;
    if (callId == null) return;
    // Guard against a duplicate `client-user-joined` (our socket delivers some
    // frames twice): if we already have a connection to this peer we've already
    // offered — re-offering would create a second SDP exchange and glare.
    if (_peerConnections.containsKey(peerId)) {
      return;
    }
    final pc = await _getOrCreatePeer(peerId);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await repository.sendOffer(callId, targetId: peerId, sdp: offer.toMap());
  }

  /// Pull the `{sdp, type}` out of a remote description payload. The web client
  /// sometimes wraps the actual session description one level deeper (e.g.
  /// `{offer: {sdp, type}}` re-nested, or a serialized RTCSessionDescription),
  /// so accept either the flat shape or a single nested `sdp`/`type` holder.
  Map<String, String>? _extractSessionDescription(Map<String, dynamic> raw) {
    dynamic sdp = raw['sdp'];
    dynamic type = raw['type'];
    if (sdp is! String || sdp.isEmpty) {
      // Look one level down for a nested description object.
      for (final value in raw.values) {
        if (value is Map && value['sdp'] is String && (value['sdp'] as String).isNotEmpty) {
          sdp = value['sdp'];
          type = value['type'] ?? type;
          break;
        }
      }
    }
    if (sdp is! String || sdp.isEmpty || type is! String || type.isEmpty) return null;
    return {'sdp': _normalizeSdp(sdp), 'type': type};
  }

  /// libwebrtc's SDP parser (used here via flutter_webrtc, and also by
  /// Chrome on the web side) is strict: every line must end with CRLF and the
  /// whole blob must end with a trailing terminator. Chrome's own
  /// createOffer()/createAnswer() output doesn't always append that final
  /// CRLF after the last attribute line — harmless for the local peer's own
  /// setLocalDescription(), but rejected by the *receiving* side's
  /// setRemoteDescription() on both platforms. Confirmed independently on
  /// the web client (resources/js/chat.js normalizeSdp) via a raw SDP dump
  /// where every line had a trailing \r except the last. Rewriting to clean
  /// CRLF with a guaranteed trailing CRLF makes the exact same offer parse,
  /// regardless of which side (web or mobile) generated it or which side is
  /// receiving it.
  String _normalizeSdp(String sdp) {
    final unified = sdp.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = unified.split('\n');
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return '${lines.join('\r\n')}\r\n';
  }

  Future<void> _handleRemoteOffer(String peerId, Map<String, dynamic> sdpMap) async {
    final callId = currentCallId;
    if (callId == null) return;
    final desc = _extractSessionDescription(sdpMap);
    if (desc == null) {
      return;
    }
    // Ignore a duplicate offer once we've already applied one for this peer
    // (frames can arrive twice). Re-applying a remote offer in a non-stable
    // signalling state is what throws "SessionDescription is NULL"/state errors.
    if (_remoteDescriptionSet.contains(peerId)) {
      return;
    }
    final pc = await _getOrCreatePeer(peerId);
    try {
      await pc.setRemoteDescription(RTCSessionDescription(desc['sdp'], desc['type']));
      _remoteDescriptionSet.add(peerId);
      await _flushPendingCandidates(peerId, pc);
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await repository.sendAnswer(callId, targetId: peerId, sdp: answer.toMap());
    } catch (_) {}
  }

  Future<void> _handleRemoteAnswer(String peerId, Map<String, dynamic> sdpMap) async {
    final pc = _peerConnections[peerId];
    if (pc == null) return;
    final desc = _extractSessionDescription(sdpMap);
    if (desc == null) {
      return;
    }
    // A duplicate answer (or an answer after we're already connected) would be
    // applied in the wrong signalling state and throw — apply only once.
    if (_remoteDescriptionSet.contains(peerId)) {
      return;
    }
    try {
      await pc.setRemoteDescription(RTCSessionDescription(desc['sdp'], desc['type']));
      _remoteDescriptionSet.add(peerId);
      await _flushPendingCandidates(peerId, pc);
    } catch (_) {}
  }

  Future<void> _handleRemoteCandidate(String peerId, Map<String, dynamic> candidateMap) async {
    final candidateStr = candidateMap['candidate'];
    if (candidateStr is! String || candidateStr.isEmpty) {
      return;
    }
    final candidate = RTCIceCandidate(
      candidateStr,
      candidateMap['sdpMid'],
      candidateMap['sdpMLineIndex'] is int ? candidateMap['sdpMLineIndex'] : null,
    );
    final pc = _peerConnections[peerId];
    if (pc == null || !_remoteDescriptionSet.contains(peerId)) {
      (_pendingCandidates[peerId] ??= []).add(candidate);
      return;
    }
    await pc.addCandidate(candidate);
  }

  Future<void> _flushPendingCandidates(String peerId, RTCPeerConnection pc) async {
    final pending = _pendingCandidates.remove(peerId);
    if (pending == null) return;
    for (final candidate in pending) {
      await pc.addCandidate(candidate);
    }
  }

  // ---- Realtime event handling ----

  void _onRealtimeEvent(RealtimeEvent event) {
    final callId = currentCallId;
    if (callId == null) return;

    // user.{myId} channel events
    if (event.eventName == RealtimeEventNames.callAnswered && isCaller) {
      final call = event.data['call'];
      if (call is! Map || call['id']?.toString() != callId) return;
      _ringTimeout?.cancel();
      // Only advance the UI here. The WebRTC offer is initiated when the callee
      // announces itself via `client-user-joined` (handled below), so a single
      // code path drives both 1:1 and group calls and neither side offers twice.
      _eventsController.add(CallServiceEvent(CallServiceEventType.answered, call: currentCall));
      return;
    }
    if (event.eventName == RealtimeEventNames.callDeclined) {
      final targetCallId = (event.data['call'] as Map?)?['id']?.toString();
      if (targetCallId != callId) return;
      _eventsController.add(const CallServiceEvent(CallServiceEventType.declined));
      _teardown();
      return;
    }

    // call.{callId} channel events
    if (event.channelName != RealtimeChannels.call(callId)) return;

    switch (event.eventName) {
      case RealtimeEventNames.clientUserJoined:
        final userId = event.data['userId']?.toString();
        if (userId == null || userId == myUserId) return;
        _rememberPeerIdentity(userId, event.data['userName']?.toString(), event.data['userPhoto']?.toString());
        // Every existing participant offers to the newcomer (joiner only answers) to avoid glare.
        _initiateOfferTo(userId);
        break;
      case RealtimeEventNames.clientUserLeft:
        // Explicit "I'm leaving" signal (see CallController::end/decline for
        // a group call) — a clean, immediate alternative to waiting out
        // WebRTC's own ICE-disconnect detection, which can take many
        // seconds (or never trigger cleanly) once the peer's side has
        // actually stopped sending.
        final leftUserId = event.data['userId']?.toString();
        if (leftUserId == null || leftUserId == myUserId) return;
        _removePeer(leftUserId);
        if (_peerConnections.isEmpty) {
          endCall();
        } else {
          _eventsController.add(CallServiceEvent(CallServiceEventType.peerLeft, peerId: leftUserId));
        }
        break;
      case RealtimeEventNames.clientWebrtcSignal:
        final senderId = event.data['senderId']?.toString();
        if (senderId == null || senderId == myUserId) return;
        _rememberPeerIdentity(senderId, event.data['senderName']?.toString(), event.data['senderPhoto']?.toString());
        if (event.data['offer'] != null) {
          _handleRemoteOffer(senderId, Map<String, dynamic>.from(event.data['offer']));
        } else if (event.data['answer'] != null) {
          _handleRemoteAnswer(senderId, Map<String, dynamic>.from(event.data['answer']));
        } else if (event.data['candidate'] != null) {
          _handleRemoteCandidate(senderId, Map<String, dynamic>.from(event.data['candidate']));
        }
        break;
    }
  }

  void _rememberPeerIdentity(String peerId, String? name, String? photo) {
    if (name != null && name.isNotEmpty) _peerNames[peerId] = name;
    if (photo != null && photo.isNotEmpty) _peerPhotos[peerId] = photo;
  }

  Future<void> _teardown() async {
    _ringTimeout?.cancel();
    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    _pendingCandidates.clear();
    _remoteDescriptionSet.clear();
    remoteStreams.clear();
    _peerNames.clear();
    _peerPhotos.clear();
    await localStream?.dispose();
    localStream = null;
    if (currentCallId != null) {
      await pusher.unsubscribe(RealtimeChannels.call(currentCallId!));
    }
    currentCallId = null;
    currentCall = null;
    isCaller = false;
  }

  void toggleMute() {
    final tracks = localStream?.getAudioTracks() ?? [];
    for (final t in tracks) {
      t.enabled = !t.enabled;
    }
  }

  void toggleCamera() {
    final tracks = localStream?.getVideoTracks() ?? [];
    for (final t in tracks) {
      t.enabled = !t.enabled;
    }
  }

  void switchCamera() {
    final tracks = localStream?.getVideoTracks() ?? [];
    if (tracks.isNotEmpty) Helper.switchCamera(tracks.first);
  }

  void dispose() {
    _frameSub?.cancel();
    _teardown();
    _eventsController.close();
  }
}
