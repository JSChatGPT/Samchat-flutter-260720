import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../chats/application/inbox_notifier.dart';
import '../../../settings/application/profile_notifier.dart';
import '../../application/user_profile_provider.dart';

/// WhatsApp-style "contact info" screen — reached by tapping a name/avatar
/// anywhere in a chat or group (chat header, a sender's name in a group
/// bubble, or a member row in Group info). Read-only about the person
/// themselves; the only mutations available are ones the *viewer* performs
/// (start a chat/call, block/unblock) — nothing here edits the viewed
/// user's own data.
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _busy = false;

  Future<void> _startChat() async {
    setState(() => _busy = true);
    try {
      final chat = await ref.read(chatsRepositoryProvider).createOrGetDirectChat(widget.userId);
      if (!mounted) return;
      context.pushNamed(RouteNames.chatDetail, pathParameters: {'chatId': chat.id});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _call(bool video) {
    context.pushNamed(RouteNames.outgoingCall, extra: {'receiverId': widget.userId, 'video': video});
  }

  Future<void> _toggleBlock(bool currentlyBlocked) async {
    final confirmed = currentlyBlocked
        ? true
        : await showConfirmDialog(
            context,
            title: 'Block this contact?',
            message: "You won't receive messages or calls from them anymore.",
            confirmLabel: 'Block',
            destructive: true,
          );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      if (currentlyBlocked) {
        await repo.unblock(widget.userId);
      } else {
        await repo.block(widget.userId);
      }
      ref.invalidate(isUserBlockedProvider(widget.userId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.watch(currentUserIdProvider);
    final isSelf = widget.userId == myUserId;
    final profileAsync = ref.watch(userProfileProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Contact info')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load profile: $e')),
        data: (data) {
          final user = data.user;
          final scheme = Theme.of(context).colorScheme;
          final blockedAsync = isSelf ? null : ref.watch(isUserBlockedProvider(widget.userId));
          final isBlocked = blockedAsync?.valueOrNull ?? false;

          return ListView(
            children: [
              const SizedBox(height: 24),
              Center(child: AppAvatar(photoUrl: user.photoUrl, initials: user.initials, size: 120)),
              const SizedBox(height: 16),
              Text(user.displayName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              if (!isSelf)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    AppDateUtils.lastSeen(user.lastSeenAt),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (!isSelf) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionButton(icon: Icons.chat_bubble_outline, label: 'Message', onTap: _busy ? null : _startChat),
                    _ActionButton(icon: Icons.call_outlined, label: 'Audio', onTap: _busy ? null : () => _call(false)),
                    _ActionButton(icon: Icons.videocam_outlined, label: 'Video', onTap: _busy ? null : () => _call(true)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),
              if (user.aboutStatus != null && user.aboutStatus!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(user.aboutStatus!),
                  subtitle: const Text('About'),
                ),
              if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(user.phoneNumber!),
                  subtitle: const Text('Phone'),
                ),
              if (!isSelf && data.sharedGroupsCount > 0)
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text('${data.sharedGroupsCount} group${data.sharedGroupsCount == 1 ? '' : 's'} in common'),
                ),
              if (!isSelf) ...[
                const Divider(),
                ListTile(
                  leading: Icon(isBlocked ? Icons.check_circle_outline : Icons.block, color: scheme.error),
                  title: Text(
                    isBlocked ? 'Unblock' : 'Block',
                    style: TextStyle(color: scheme.error),
                  ),
                  onTap: _busy ? null : () => _toggleBlock(isBlocked),
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
