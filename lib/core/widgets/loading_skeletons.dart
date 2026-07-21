import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Wraps [child] in a Skeletonizer shimmer while [loading] is true — used on
/// inbox/chat/status list screens' first load.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, required this.loading, required this.child});

  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(enabled: loading, child: child);
  }
}

class InboxTileSkeleton extends StatelessWidget {
  const InboxTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: CircleAvatar(radius: 26),
      title: Text('Loading name placeholder'),
      subtitle: Text('Loading last message preview'),
      trailing: Text('00:00'),
    );
  }
}
