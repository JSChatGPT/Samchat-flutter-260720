import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../core/widgets/app_avatar.dart';

class ParticipantTile extends StatelessWidget {
  const ParticipantTile({
    super.key,
    this.renderer,
    required this.name,
    this.photoUrl,
    required this.showVideo,
  });

  final RTCVideoRenderer? renderer;
  final String name;
  final String? photoUrl;
  final bool showVideo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.grey.shade900,
        child: (showVideo && renderer != null)
            ? RTCVideoView(renderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            : Center(
                child: AppAvatar(
                  photoUrl: photoUrl,
                  initials: name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                  size: 72,
                ),
              ),
      ),
    );
  }
}
