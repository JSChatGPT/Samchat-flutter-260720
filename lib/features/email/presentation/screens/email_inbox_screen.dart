import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../models/email_account.dart';
import '../../../../models/email_message.dart';
import '../../application/email_notifier.dart';
import 'compose_email_screen.dart';
import 'email_detail_screen.dart';

class EmailInboxScreen extends ConsumerStatefulWidget {
  const EmailInboxScreen({super.key, required this.account});

  final EmailAccount account;

  @override
  ConsumerState<EmailInboxScreen> createState() => _EmailInboxScreenState();
}

class _EmailInboxScreenState extends ConsumerState<EmailInboxScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(emailInboxNotifierProvider(widget.account.id).notifier).loadMore();
    }
  }

  Future<void> _openEmail(EmailMessage email) async {
    final wasUnread = !email.isRead;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EmailDetailScreen(account: widget.account, emailId: email.id)),
    );
    if (!mounted || !wasUnread) return;
    // The backend already marked it read as a side effect of opening it
    // (see EmailDetailScreen) — reflect that locally instead of paying for
    // another full IMAP resync just to learn what we already know.
    ref.read(emailInboxNotifierProvider(widget.account.id).notifier).markEmailRead(email.id);
    ref.read(emailAccountsNotifierProvider.notifier).decrementUnread(widget.account.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(emailInboxNotifierProvider(widget.account.id));
    return Scaffold(
      appBar: AppBar(title: Text(widget.account.emailAddress, overflow: TextOverflow.ellipsis)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'email_compose_fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ComposeEmailScreen(account: widget.account)),
        ),
        child: const Icon(Icons.edit_square),
      ),
      body: switch (state.status) {
        EmailInboxStatus.loading => const Center(child: CircularProgressIndicator()),
        EmailInboxStatus.error => ErrorStateWidget(
            message: state.error ?? 'Could not load inbox',
            onRetry: () => ref.read(emailInboxNotifierProvider(widget.account.id).notifier).refresh(),
          ),
        EmailInboxStatus.loaded => state.emails.isEmpty
            ? const EmptyStateWidget(icon: Icons.inbox_outlined, title: 'No emails yet')
            : RefreshIndicator(
                onRefresh: () => ref.read(emailInboxNotifierProvider(widget.account.id).notifier).refresh(),
                child: ListView.separated(
                  controller: _scrollController,
                  itemCount: state.emails.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 16),
                  itemBuilder: (context, index) {
                    if (index >= state.emails.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final email = state.emails[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(email.senderDisplay.isNotEmpty ? email.senderDisplay[0].toUpperCase() : '?'),
                      ),
                      title: Text(
                        email.senderDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: email.isRead ? FontWeight.normal : FontWeight.bold),
                      ),
                      subtitle: Text(
                        email.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: email.isRead ? FontWeight.normal : FontWeight.bold),
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(AppDateUtils.inboxTimestamp(email.receivedAt), style: Theme.of(context).textTheme.bodySmall),
                          if (email.hasAttachments) ...[
                            const SizedBox(height: 4),
                            Icon(Icons.attach_file, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ],
                        ],
                      ),
                      onTap: () => _openEmail(email),
                    );
                  },
                ),
              ),
      },
    );
  }
}
