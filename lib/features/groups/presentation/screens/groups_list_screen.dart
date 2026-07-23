import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../models/chat.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../chats/application/inbox_notifier.dart';
import '../../../chats/presentation/widgets/chat_list_tile.dart';

/// Derived from the already-loaded, already-realtime [inboxNotifierProvider]
/// rather than a second `/chats?filter=groups` fetch + pusher subscription —
/// the inbox already holds every chat the user participates in (see
/// InboxNotifier), so this is just a filter over state that's already live.
final groupChatsProvider = Provider.autoDispose((ref) {
  return ref.watch(inboxNotifierProvider).chats.where((c) => c.isGroup).toList();
});

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupChatsProvider);
    final inboxState = ref.watch(inboxNotifierProvider);
    final myUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'groups_fab',
        onPressed: () => context.pushNamed(RouteNames.createGroup),
        child: const Icon(Icons.group_add_outlined),
      ),
      body: _buildBody(context, ref, groups, inboxState, myUserId),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<Chat> groups,
    InboxState inboxState,
    String myUserId,
  ) {
    if (inboxState.status == InboxLoadStatus.loading && groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (groups.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.groups_outlined,
        title: 'No groups yet',
        message: 'Groups you create or join will show up here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(inboxNotifierProvider.notifier).refresh(),
      child: ListView.separated(
        itemCount: groups.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
        itemBuilder: (context, index) {
          final chat = groups[index];
          return ChatListTile(
            chat: chat,
            myUserId: myUserId,
            isTyping: inboxState.typingChatIds.contains(chat.id),
            onTap: () {
              ref.read(inboxNotifierProvider.notifier).markChatRead(chat.id);
              context.pushNamed(RouteNames.chatDetail, pathParameters: {'chatId': chat.id});
            },
            onMute: () => ref.read(inboxNotifierProvider.notifier).toggleMute(chat.id),
            onDelete: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Delete group',
                message: 'This removes the group from your inbox.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (confirmed) {
                await ref.read(inboxNotifierProvider.notifier).deleteChat(chat.id);
              }
            },
          );
        },
      ),
    );
  }
}
