import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/count_badge.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../models/email_account.dart';
import '../../application/email_notifier.dart';
import 'connect_email_screen.dart';
import 'email_inbox_screen.dart';

class EmailAccountsScreen extends ConsumerWidget {
  const EmailAccountsScreen({super.key});

  Future<void> _addAccount(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectEmailScreen()));
  }

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref, EmailAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink account'),
        content: Text('Stop syncing ${account.emailAddress}? Downloaded emails will be removed from SamChat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unlink')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(emailAccountsNotifierProvider.notifier).disconnect(account.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(emailAccountsNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email'),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Link account', onPressed: () => _addAccount(context)),
        ],
      ),
      body: switch (state.status) {
        EmailAccountsStatus.loading => const Center(child: CircularProgressIndicator()),
        EmailAccountsStatus.error => ErrorStateWidget(
            message: state.error ?? 'Could not load email accounts',
            onRetry: () => ref.read(emailAccountsNotifierProvider.notifier).refresh(),
          ),
        EmailAccountsStatus.loaded => state.accounts.isEmpty
            ? EmptyStateWidget(
                icon: Icons.mail_outline,
                title: 'Link your email',
                message: 'Connect a Gmail or Yahoo account to read and send email right from SamChat.',
                action: ElevatedButton(onPressed: () => _addAccount(context), child: const Text('Link an account')),
              )
            : RefreshIndicator(
                onRefresh: () => ref.read(emailAccountsNotifierProvider.notifier).refresh(),
                child: ListView.separated(
                  itemCount: state.accounts.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
                  itemBuilder: (context, index) {
                    final account = state.accounts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(account.provider == EmailProvider.gmail ? Icons.mail_outline : Icons.alternate_email),
                      ),
                      title: Text(
                        account.emailAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: account.unreadCount > 0 ? FontWeight.bold : FontWeight.normal),
                      ),
                      subtitle: Text(account.provider.label),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CountBadge(count: account.unreadCount),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.link_off),
                            tooltip: 'Unlink',
                            onPressed: () => _confirmDisconnect(context, ref, account),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => EmailInboxScreen(account: account)),
                      ),
                    );
                  },
                ),
              ),
      },
    );
  }
}
