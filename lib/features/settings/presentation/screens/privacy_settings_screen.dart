import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../application/app_lock_notifier.dart';
import '../../application/privacy_notifier.dart';

const _options = {
  'everyone': ('Everyone', 'All SamChat users can see your status'),
  'contacts': ('My contacts', 'Only people you\'ve saved can see your status'),
  'selected': ('Selected contacts', 'Only contacts you choose'),
  'exclude': ('My contacts except…', 'Your contacts, except people you choose'),
};

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(privacyNotifierProvider);
    final lockEnabled = ref.watch(appLockSettingsNotifierProvider).enabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Who can see your status updates'),
                ),
                RadioGroup<String>(
                  groupValue: state.privacy,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(privacyNotifierProvider.notifier).setPrivacy(value);
                    }
                  },
                  child: Column(
                    children: _options.entries.map((entry) {
                      return RadioListTile<String>(
                        value: entry.key,
                        title: Text(entry.value.$1),
                        subtitle: Text(entry.value.$2),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('Fingerprint lock'),
                  subtitle: Text(lockEnabled ? 'On' : 'Off'),
                  onTap: () => context.pushNamed(RouteNames.appLockSettings),
                ),
              ],
            ),
    );
  }
}
