import 'package:flutter/material.dart';

class CallControlsBar extends StatelessWidget {
  const CallControlsBar({
    super.key,
    required this.isMuted,
    required this.isCameraOff,
    required this.isSpeakerOn,
    required this.isVideo,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onToggleSpeaker,
    required this.onSwitchCamera,
    required this.onEnd,
  });

  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final bool isVideo;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onSwitchCamera;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon: isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
          active: isSpeakerOn,
          label: 'Speaker',
          onTap: onToggleSpeaker,
        ),
        _ControlButton(
          icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          active: isMuted,
          label: 'Mute',
          onTap: onToggleMute,
        ),
        if (isVideo) ...[
          _ControlButton(
            icon: isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            active: isCameraOff,
            label: 'Camera',
            onTap: onToggleCamera,
          ),
          _ControlButton(
            icon: Icons.cameraswitch_rounded,
            active: false,
            label: 'Flip',
            onTap: onSwitchCamera,
          ),
        ],
        _ControlButton(
          icon: Icons.call_end_rounded,
          active: true,
          activeColor: Theme.of(context).colorScheme.error,
          label: 'End',
          onTap: onEnd,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.label,
    this.activeColor,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String label;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? Colors.white24) : Colors.white24;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
