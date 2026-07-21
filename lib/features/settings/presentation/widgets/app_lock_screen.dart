import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../application/app_lock_gate.dart';

/// Full-screen overlay shown whenever [appLockGateProvider] is true — cold
/// start with the lock enabled, or resuming after being backgrounded longer
/// than the selected timeout. Prompts biometrics automatically as soon as it
/// appears (no tap needed first, matching WhatsApp), with a retry button for
/// when the system prompt is dismissed or fails.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final ok = await ref.read(biometricAuthServiceProvider).authenticate(
          reason: 'Unlock SamChat',
        );
    if (!mounted) return;
    setState(() => _authenticating = false);
    if (ok) {
      ref.read(appLockGateProvider.notifier).unlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/samchat_logo.png', width: 96, height: 96),
                const SizedBox(height: 24),
                Text('SamChat is locked', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Unlock with your fingerprint to continue',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),
                _authenticating
                    ? const CircularProgressIndicator()
                    : FilledButton.icon(
                        onPressed: _authenticate,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Unlock'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
