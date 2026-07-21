import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/connectivity_service.dart';

/// Thin persistent banner shown at the top of every screen while offline —
/// wrap `MaterialApp.router`'s `builder` with this.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: isOnline ? 0 : MediaQuery.of(context).padding.top + 28,
          color: Theme.of(context).colorScheme.error,
          alignment: Alignment.bottomCenter,
          child: isOnline
              ? null
              : const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'No internet connection',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
