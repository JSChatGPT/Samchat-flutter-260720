import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../models/sms_conversation.dart';
import '../../application/sms_notifier.dart';
import 'sms_contact_picker_screen.dart';

class SmsInboxScreen extends ConsumerWidget {
  const SmsInboxScreen({super.key});

  Future<void> _composeNew(BuildContext context, WidgetRef ref) async {
    String enteredAddress = '';
    final address = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New message', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.contacts_outlined),
              title: const Text('Choose from contacts'),
              onTap: () async {
                final picked = await Navigator.of(ctx).push<String>(
                  MaterialPageRoute(builder: (_) => const SmsContactPickerScreen()),
                );
                if (picked != null && picked.isNotEmpty && ctx.mounted) Navigator.pop(ctx, picked);
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('or')), Expanded(child: Divider())]),
            ),
            IntlPhoneField(
              decoration: const InputDecoration(labelText: 'Type a number'),
              initialCountryCode: 'ZM',
              onChanged: (phone) => enteredAddress = phone.completeNumber,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, enteredAddress),
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
    if (address == null || address.isEmpty || !context.mounted) return;
    context.pushNamed(
      RouteNames.smsThread,
      extra: SmsThreadArgs(threadId: '', address: address),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(smsInboxNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_square), tooltip: 'New message', onPressed: () => _composeNew(context, ref)),
        ],
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, SmsInboxState state) {
    switch (state.status) {
      case SmsInboxStatus.notDefault:
        return EmptyStateWidget(
          icon: Icons.sms_outlined,
          title: 'Read & reply to texts here',
          message: 'Make SamChat your default SMS app to see and send text messages in this tab. '
              'This replaces your phone\'s current default messaging app.',
          action: ElevatedButton(
            onPressed: () => ref.read(smsInboxNotifierProvider.notifier).requestDefault(),
            child: const Text('Make default'),
          ),
        );
      case SmsInboxStatus.loading:
        if (state.conversations.isEmpty) return const Center(child: CircularProgressIndicator());
        return _buildList(context, ref, state.conversations);
      case SmsInboxStatus.error:
        return ErrorStateWidget(
          message: state.error ?? 'Could not load messages',
          onRetry: () => ref.read(smsInboxNotifierProvider.notifier).refresh(),
        );
      case SmsInboxStatus.ready:
        if (state.conversations.isEmpty) {
          return const EmptyStateWidget(icon: Icons.sms_outlined, title: 'No messages yet');
        }
        return _buildList(context, ref, state.conversations);
    }
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<SmsConversation> conversations) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () => ref.read(smsInboxNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          return ListTile(
            leading: AppAvatar(initials: conversation.title.isNotEmpty ? conversation.title[0].toUpperCase() : '?'),
            title: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(conversation.snippet, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppDateUtils.inboxTimestamp(conversation.date), style: Theme.of(context).textTheme.bodySmall),
                if (conversation.unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                      style: TextStyle(color: scheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () {
              ref.read(smsInboxNotifierProvider.notifier).markThreadRead(conversation.threadId);
              context.pushNamed(
                RouteNames.smsThread,
                extra: SmsThreadArgs(threadId: conversation.threadId, address: conversation.address),
              );
            },
          );
        },
      ),
    );
  }
}
