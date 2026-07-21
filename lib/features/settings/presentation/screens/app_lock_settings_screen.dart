import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../application/app_lock_notifier.dart';

class AppLockSettingsScreen extends ConsumerWidget {
  const AppLockSettingsScreen({super.key});

  Future<void> _onToggle(BuildContext context, WidgetRef ref, bool value) async {
    final notifier = ref.read(appLockSettingsNotifierProvider.notifier);
    if (!value) {
      await notifier.setEnabled(false);
      return;
    }

    final biometrics = ref.read(biometricAuthServiceProvider);
    if (!await biometrics.isSupported) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fingerprint, face, or screen lock is set up on this device')),
      );
      return;
    }

    // Confirm the sensor actually works before committing to locking the
    // user out of their own chats behind it.
    final ok = await biometrics.authenticate(reason: 'Confirm to turn on fingerprint lock');
    if (ok) {
      await notifier.setEnabled(true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appLockSettingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fingerprint lock')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Unlock with fingerprint'),
            subtitle: const Text('Require your fingerprint to open SamChat'),
            value: settings.enabled,
            onChanged: (value) => _onToggle(context, ref, value),
          ),
          if (settings.enabled) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Require after'),
            ),
            RadioGroup<AppLockTimeout>(
              groupValue: settings.timeout,
              onChanged: (value) {
                if (value != null) {
                  ref.read(appLockSettingsNotifierProvider.notifier).setTimeout(value);
                }
              },
              child: Column(
                children: [
                  for (final timeout in AppLockTimeout.values)
                    RadioListTile<AppLockTimeout>(
                      value: timeout,
                      title: Text(timeout.label),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
