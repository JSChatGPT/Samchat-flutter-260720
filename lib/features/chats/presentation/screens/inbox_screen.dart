import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../application/inbox_notifier.dart';
import '../../data/chats_repository.dart';
import '../widgets/chat_list_tile.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inboxNotifierProvider);
    final myUserId = ref.watch(currentUserIdProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(inboxSearchFocusRequestProvider, (previous, next) {
      if (previous != next) _searchFocusNode.requestFocus();
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'inbox_fab',
        onPressed: () => _showNewChatMenu(context),
        child: const Icon(Icons.message),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: isDark ? scheme.surfaceContainerHigh : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (v) => ref.read(inboxNotifierProvider.notifier).setSearch(v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: state.filter == InboxFilter.all,
                  onTap: () => ref.read(inboxNotifierProvider.notifier).setFilter(InboxFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Unread',
                  selected: state.filter == InboxFilter.unread,
                  onTap: () => ref.read(inboxNotifierProvider.notifier).setFilter(InboxFilter.unread),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Groups',
                  selected: state.filter == InboxFilter.groups,
                  onTap: () => ref.read(inboxNotifierProvider.notifier).setFilter(InboxFilter.groups),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(state, myUserId)),
        ],
      ),
    );
  }

  void _showNewChatMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('New chat'),
              onTap: () {
                Navigator.pop(ctx);
                context.pushNamed(RouteNames.contactPicker);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('New group'),
              onTap: () {
                Navigator.pop(ctx);
                context.pushNamed(RouteNames.createGroup);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('New meeting'),
              onTap: () {
                Navigator.pop(ctx);
                context.pushNamed(RouteNames.scheduleMeeting);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(InboxState state, String myUserId) {
    if (state.status == InboxLoadStatus.loading && state.chats.isEmpty) {
      return AppSkeleton(
        loading: true,
        child: ListView.builder(
          itemCount: 8,
          itemBuilder: (context, index) => const InboxTileSkeleton(),
        ),
      );
    }
    if (state.status == InboxLoadStatus.error && state.chats.isEmpty) {
      return ErrorStateWidget(
        message: state.error ?? 'Could not load chats',
        onRetry: () => ref.read(inboxNotifierProvider.notifier).refresh(),
      );
    }
    if (state.chats.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No chats yet',
        message: 'Start a conversation with the + button below.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(inboxNotifierProvider.notifier).refresh(),
      child: ListView.separated(
        itemCount: state.chats.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
        itemBuilder: (context, index) {
          final chat = state.chats[index];
          return ChatListTile(
            chat: chat,
            myUserId: myUserId,
            isTyping: state.typingChatIds.contains(chat.id),
            onTap: () {
              ref.read(inboxNotifierProvider.notifier).markChatRead(chat.id);
              context.pushNamed(RouteNames.chatDetail, pathParameters: {'chatId': chat.id});
            },
            onMute: () => ref.read(inboxNotifierProvider.notifier).toggleMute(chat.id),
            onDelete: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Delete chat',
                message: 'This removes the chat from your inbox.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (confirmed && mounted) {
                await ref.read(inboxNotifierProvider.notifier).deleteChat(chat.id);
              }
            },
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
