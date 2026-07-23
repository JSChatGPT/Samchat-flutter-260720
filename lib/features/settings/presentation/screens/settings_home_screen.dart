import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../application/theme_mode_notifier.dart';

class SettingsHomeScreen extends ConsumerWidget {
  const SettingsHomeScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out',
      message: 'You\'ll need to verify your phone number again to log back in.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  Future<void> _requestBatteryExemption(BuildContext context, WidgetRef ref) async {
    final granted = await ref.read(pushServiceProvider).requestBatteryOptimizationExemption();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Background access allowed — notifications and calls will arrive reliably.'
              : 'Not allowed. You can also enable this from your phone\'s battery settings for Samchat.',
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            for (final entry in const {
              ThemeMode.system: 'System default',
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
            }.entries)
              ListTile(
                title: Text(entry.value),
                trailing: ref.watch(themeModeNotifierProvider) == entry.key
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  ref.read(themeModeNotifierProvider.notifier).setMode(entry.key);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: AppAvatar(photoUrl: me?.photoUrl, initials: me?.initials ?? '?', size: 56),
            title: Text(me?.displayName ?? '', style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(me?.aboutStatus ?? 'Hey there! I am using Samchat.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed(RouteNames.profileEdit),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacy'),
            subtitle: const Text('Who can see your status updates'),
            onTap: () => context.pushNamed(RouteNames.privacySettings),
          ),
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: const Text('Blocked users'),
            onTap: () => context.pushNamed(RouteNames.blockedUsers),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Theme'),
            onTap: () => _showThemePicker(context, ref),
          ),
          if (Platform.isAndroid)
            ListTile(
              leading: const Icon(Icons.battery_charging_full_outlined),
              title: const Text('Background notifications'),
              subtitle: const Text('Allow Samchat to run in the background for reliable notifications and calls'),
              onTap: () => _requestBatteryExemption(context, ref),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => context.pushNamed(RouteNames.about),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('Log out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => _logout(context, ref),
          ),
        ],
      ),
    );
  }
}
