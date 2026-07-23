import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/crypto/backup/backup_service_provider.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Shown once, right after login, only when this device has no local E2EE
/// identity yet (fresh install, reinstall, or new phone) and an encrypted
/// backup was found in the user's own cloud storage — see
/// SamChatApp._setupE2eeIdentity. Restoring the backup recovers this
/// device's original chat identity, which makes every chat's entire
/// history immediately readable again, with no waiting on the self-heal
/// path at all.
class ChatBackupRestoreScreen extends ConsumerStatefulWidget {
  const ChatBackupRestoreScreen({super.key});

  @override
  ConsumerState<ChatBackupRestoreScreen> createState() => _ChatBackupRestoreScreenState();
}

class _ChatBackupRestoreScreenState extends ConsumerState<ChatBackupRestoreScreen> {
  final _passwordController = TextEditingController();
  bool _isRestoring = false;
  bool _obscure = true;
  String? _error;
  int _attempts = 0;

  static const _maxAttempts = 5;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // Registers whatever identity is in secure storage now — either the
    // one just restored, or (on skip) a brand-new one ensureDeviceRegistered
    // generates itself when it finds none.
    await ref.read(e2eeServiceProvider).ensureDeviceRegistered();
    if (mounted) context.goNamed(RouteNames.chats);
  }

  Future<void> _restore() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;
    setState(() {
      _isRestoring = true;
      _error = null;
    });

    final ok = await ref.read(chatBackupServiceProvider).restoreFromBackup(password);
    if (!mounted) return;

    if (ok) {
      await _finish();
      return;
    }

    _attempts++;
    setState(() {
      _isRestoring = false;
      _error = _attempts >= _maxAttempts
          ? 'Still incorrect. You can try again later from Settings, or skip for now.'
          : 'Incorrect password. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(20)),
                  child: Icon(Icons.cloud_download_outlined, color: scheme.onPrimary, size: 36),
                ),
                const SizedBox(height: 24),
                Text('Restore your chats', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  'We found an encrypted backup of your chats. Enter your backup password to '
                  'restore access to your entire chat history on this device.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Only you know this password — we can\'t reset it for you.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                AppTextField(
                  controller: _passwordController,
                  label: 'Backup password',
                  obscureText: _obscure,
                  autofocus: true,
                  enabled: !_isRestoring,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isRestoring ? null : _restore,
                    child: _isRestoring
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Restore'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _isRestoring ? null : _finish,
                    child: const Text('Skip — start fresh'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
