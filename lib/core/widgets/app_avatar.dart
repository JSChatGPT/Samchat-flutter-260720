import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.photoUrl,
    required this.initials,
    this.size = 48,
    this.showOnlineDot = false,
    this.isOnline = false,
    this.isGroup = false,
    this.heroTag,
  });

  final String? photoUrl;
  final String initials;
  final double size;
  final bool showOnlineDot;
  final bool isOnline;

  /// Small badge in the same corner slot as the online dot — the two never
  /// apply to the same chat (a chat is either a group or has a single other
  /// participant to show online status for), so they share one slot.
  final bool isGroup;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
          ? CachedNetworkImageProvider(photoUrl!)
          : null,
      child: (photoUrl == null || photoUrl!.isEmpty)
          ? Text(
              initials,
              style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w400),
            )
          : null,
    );

    if (heroTag != null) {
      avatar = Hero(tag: heroTag!, child: avatar);
    }

    if (!showOnlineDot && !isGroup) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (showOnlineDot && isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        if (isGroup)
          Positioned(
            bottom: -1,
            right: -1,
            child: Container(
              width: size * 0.36,
              height: size * 0.36,
              decoration: BoxDecoration(
                color: scheme.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
              child: Icon(Icons.groups_rounded, size: size * 0.22, color: scheme.onSecondary),
            ),
          ),
      ],
    );
  }
}
