import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../application/call_notifier.dart';
import '../../application/call_state.dart';
import '../../application/incoming_call_listener.dart';
import '../widgets/call_controls_bar.dart';
import '../widgets/participant_tile.dart';

/// Single screen for the whole call lifecycle (ringing → connecting →
/// active) — WhatsApp/Messenger-style, no separate navigation between
/// "outgoing"/"incoming"/"in-call" states, just different renders of the
/// same [CallSessionState.phase].
///
/// Three entry modes:
/// - Outgoing 1:1: pass [outgoingReceiverId] + [outgoingVideo] — the screen
///   initiates the call itself.
/// - Outgoing group: pass [outgoingChatId] + [outgoingVideo] instead — rings
///   every other participant of that chat.
/// - Incoming/already-active: leave all three null — the screen just
///   reflects whatever [CallService] already has in flight (primed by
///   [incomingCallListenerProvider] before this route was pushed).
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key, this.outgoingReceiverId, this.outgoingChatId, this.outgoingVideo});

  final String? outgoingReceiverId;
  final String? outgoingChatId;
  final bool? outgoingVideo;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.outgoingChatId != null) {
        ref.read(callNotifierProvider.notifier).startOutgoingGroupCall(
              chatId: widget.outgoingChatId!,
              video: widget.outgoingVideo ?? false,
            );
      } else if (widget.outgoingReceiverId != null) {
        ref.read(callNotifierProvider.notifier).startOutgoingCall(
              receiverId: widget.outgoingReceiverId!,
              video: widget.outgoingVideo ?? false,
            );
      } else {
        ref.read(callNotifierProvider.notifier).prepareIncoming();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callNotifierProvider);

    ref.listen(callNotifierProvider, (prev, next) {
      if (next.phase == CallPhase.ended || next.phase == CallPhase.failed) {
        ref.read(incomingCallProvider.notifier).state = null;
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      }
    });

    final myUserId = ref.watch(currentUserIdProvider);
    final call = state.call;
    // For a group call this is the group's name/photo; for 1:1 it's the
    // other person's — see CallRecord.title()/photoUrl().
    final callTitle = call?.title(myUserId);
    final callPhoto = call?.photoUrl(myUserId);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF161311),
        body: SafeArea(
          child: switch (state.phase) {
            CallPhase.outgoingRinging || CallPhase.incomingRinging => _RingingView(
                state: state,
                counterpartName: callTitle ?? 'Unknown',
                counterpartPhoto: callPhoto,
                isIncoming: state.phase == CallPhase.incomingRinging,
              ),
            CallPhase.connecting || CallPhase.active => _ActiveView(
                state: state,
                counterpartName: callTitle ?? 'Participant',
                counterpartPhoto: callPhoto,
              ),
            _ => const Center(child: CircularProgressIndicator(color: Colors.white)),
          },
        ),
      ),
    );
  }
}

class _RingingView extends ConsumerWidget {
  const _RingingView({
    required this.state,
    required this.counterpartName,
    required this.counterpartPhoto,
    required this.isIncoming,
  });

  final CallSessionState state;
  final String counterpartName;
  final String? counterpartPhoto;
  final bool isIncoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      // A bare Column here sizes itself to its widest child (the avatar/
      // text block) instead of the full screen width, so — since nothing
      // was left to center *that shrunk column* within the screen — every
      // child ended up pinned to the left edge instead of centered. The
      // gradient also gives the screen some actual visual depth instead of
      // a single flat color.
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1F1A16), Color(0xFF161311)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(height: 56),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GlowingAvatar(photoUrl: counterpartPhoto, initials: counterpartName.substring(0, 1).toUpperCase()),
              const SizedBox(height: 24),
              Text(
                counterpartName,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(
                isIncoming ? '${state.isVideo ? "Video" : "Voice"} call…' : 'Calling…',
                style: const TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 0.2),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: isIncoming
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundActionButton(
                        icon: Icons.call_end_rounded,
                        color: const Color(0xFFE53935),
                        label: 'Decline',
                        onTap: () => ref.read(callNotifierProvider.notifier).decline(),
                      ),
                      _RoundActionButton(
                        icon: Icons.call_rounded,
                        color: const Color(0xFF43A047),
                        label: 'Accept',
                        onTap: () => ref.read(callNotifierProvider.notifier).accept(),
                      ),
                    ],
                  )
                : _RoundActionButton(
                    icon: Icons.call_end_rounded,
                    color: const Color(0xFFE53935),
                    label: 'Cancel',
                    onTap: () => ref.read(callNotifierProvider.notifier).end(),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The ringing-state avatar with a soft accent-colored halo behind it —
/// purely decorative (no animation), just enough to keep the screen from
/// reading as flat/idle while nothing else is moving yet.
class _GlowingAvatar extends StatelessWidget {
  const _GlowingAvatar({required this.photoUrl, required this.initials});

  final String? photoUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 6),
        ],
      ),
      child: AppAvatar(photoUrl: photoUrl, initials: initials, size: 116),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({required this.icon, required this.color, required this.onTap, required this.label});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}

class _ActiveView extends ConsumerStatefulWidget {
  const _ActiveView({required this.state, required this.counterpartName, required this.counterpartPhoto});

  final CallSessionState state;
  final String counterpartName;
  final String? counterpartPhoto;

  @override
  ConsumerState<_ActiveView> createState() => _ActiveViewState();
}

class _ActiveViewState extends ConsumerState<_ActiveView> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // The elapsed-time label is otherwise only recomputed whenever some
    // *other* state change happens to trigger a rebuild — without a ticker
    // forcing one every second, the call screen just sits there showing a
    // stale duration, which reads as the call having frozen/gone idle even
    // though it's still very much connected.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final counterpartName = widget.counterpartName;
    final counterpartPhoto = widget.counterpartPhoto;
    final participants = state.participants.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            state.phase == CallPhase.connecting ? 'Connecting…' : _elapsedLabel(state),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        Expanded(
          child: participants.isEmpty
              ? Center(
                  child: ParticipantTile(
                    name: counterpartName,
                    photoUrl: counterpartPhoto,
                    showVideo: false,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: participants.length > 1 ? 2 : 1,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    return ParticipantTile(
                      renderer: p.renderer,
                      // Each tile shows its own participant's identity (learned
                      // from signaling — see CallParticipantState.displayName),
                      // not the call-level title, so a group call with several
                      // people doesn't show the same name on every tile.
                      name: p.displayName,
                      photoUrl: p.displayPhoto,
                      showVideo: state.isVideo,
                    );
                  },
                ),
        ),
        if (state.isVideo && !state.isCameraOff && state.localRenderer != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 100,
                height: 140,
                child: ParticipantTile(renderer: state.localRenderer, name: 'You', showVideo: true),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: CallControlsBar(
            isMuted: state.isMuted,
            isCameraOff: state.isCameraOff,
            isSpeakerOn: state.isSpeakerOn,
            isVideo: state.isVideo,
            onToggleMute: () => ref.read(callNotifierProvider.notifier).toggleMute(),
            onToggleCamera: () => ref.read(callNotifierProvider.notifier).toggleCamera(),
            onToggleSpeaker: () => ref.read(callNotifierProvider.notifier).toggleSpeaker(),
            onSwitchCamera: () => ref.read(callNotifierProvider.notifier).switchCamera(),
            onEnd: () => ref.read(callNotifierProvider.notifier).end(),
          ),
        ),
      ],
    );
  }

  String _elapsedLabel(CallSessionState state) {
    final started = state.call?.acceptedAt;
    if (started == null) return '';
    final seconds = DateTime.now().difference(started).inSeconds.clamp(0, 1 << 30);
    return AppDateUtils.durationLabel(seconds);
  }
}
