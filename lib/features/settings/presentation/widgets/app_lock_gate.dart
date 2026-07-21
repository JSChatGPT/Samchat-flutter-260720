import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_notifier.dart';
import '../../../auth/application/auth_state.dart';
import '../../application/app_lock_gate.dart';
import 'app_lock_screen.dart';

/// Overlays [AppLockScreen] on top of the rest of the app (rather than
/// navigating to it) so whatever screen/scroll position was showing stays
/// intact underneath, exactly like WhatsApp's lock screen. Wrap
/// `MaterialApp.router`'s `builder` with this, outermost.
class AppLockGateOverlay extends ConsumerWidget {
  const AppLockGateOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocked = ref.watch(appLockGateProvider);
    final isAuthenticated = ref.watch(authNotifierProvider).status == AuthStatus.authenticated;
    return Stack(
      children: [
        child,
        if (isLocked && isAuthenticated) const AppLockScreen(),
      ],
    );
  }
}
