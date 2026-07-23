import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/backup/backup_service_provider.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';

/// Settings screen for the encrypted chat backup — see
/// lib/core/crypto/backup/backup_service_provider.dart for what actually
/// gets backed up (this device's identity, not message history) and why
/// that's enough to recover full chat access on a new device.
class ChatBackupSettingsScreen extends ConsumerStatefulWidget {
  const ChatBackupSettingsScreen({super.key});

  @override
  ConsumerState<ChatBackupSettingsScreen> createState() => _ChatBackupSettingsScreenState();
}

class _ChatBackupSettingsScreenState extends ConsumerState<ChatBackupSettingsScreen> {
  bool _loading = true;
  bool _hasCloudBackup = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final hasBackup = await ref.read(chatBackupServiceProvider).hasCloudBackup();
    if (!mounted) return;
    setState(() {
      _hasCloudBackup = hasBackup;
      _loading = false;
    });
  }

  Future<String?> _promptForPassword({required bool isChange}) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isChange ? 'Change backup password' : 'Set a backup password',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Only you know this password — if you lose it, this backup can never be '
                'decrypted, not even by us. Choose something you\'ll remember, and write it '
                'down somewhere safe.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: passwordController,
                label: 'Password',
                obscureText: true,
                autofocus: true,
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: confirmController,
                label: 'Confirm password',
                obscureText: true,
                validator: (v) => v != passwordController.text ? 'Passwords don\'t match' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(ctx, passwordController.text);
                    }
                  },
                  child: Text(isChange ? 'Change password' : 'Enable backup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    passwordController.dispose();
    confirmController.dispose();
    return result;
  }

  Future<void> _enableOrChangeBackup({required bool isChange}) async {
    final password = await _promptForPassword(isChange: isChange);
    if (password == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await ref.read(chatBackupServiceProvider).enableBackup(password);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(isChange ? 'Backup password changed' : 'Backup enabled')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(const SnackBar(content: Text('Couldn\'t reach your cloud storage. Try again.')));
    }
  }

  Future<void> _disableBackup() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Turn off backup',
      message: 'Your existing backup will be deleted from your cloud storage. This device keeps working '
          'normally, but a future reinstall won\'t be able to restore from it.',
      confirmLabel: 'Turn off',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _loading = true);
    await ref.read(chatBackupServiceProvider).disableBackup();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final backupService = ref.watch(chatBackupServiceProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat backup')),
      body: !backupService.isSupported
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Chat backup isn\'t available on this device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Icon(Icons.cloud_outlined, size: 56, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      _hasCloudBackup ? 'Backed up' : 'Not backed up',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Encrypted chat backup lets you restore access to your entire chat history if you '
                      'switch phones or reinstall the app. Your backup is end-to-end encrypted with a '
                      'password only you know — we can never read it, and neither can Google or Apple.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    if (!_hasCloudBackup)
                      ElevatedButton(
                        onPressed: () => _enableOrChangeBackup(isChange: false),
                        child: const Text('Set up backup'),
                      )
                    else ...[
                      OutlinedButton(
                        onPressed: () => _enableOrChangeBackup(isChange: true),
                        child: const Text('Change password'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _disableBackup,
                        style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                        child: const Text('Turn off backup'),
                      ),
                    ],
                  ],
                ),
    );
  }
}
