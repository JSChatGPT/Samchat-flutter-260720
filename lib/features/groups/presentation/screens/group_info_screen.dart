import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../models/chat_participant.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../chat_detail/application/chat_detail_notifier.dart';
import '../../../onboarding_contacts/presentation/screens/contact_picker_screen.dart';
import 'create_group_screen.dart' show groupsRepositoryProvider;

class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  bool _busy = false;

  Future<void> _renameGroup(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Group name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == currentName) return;
    if (!mounted) return;
    await ref.read(groupsRepositoryProvider).updateGroup(widget.chatId, groupName: newName);
    if (mounted) ref.invalidate(chatDetailNotifierProvider(widget.chatId));
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(groupsRepositoryProvider).uploadGroupImage(widget.chatId, file.path);
      if (mounted) ref.invalidate(chatDetailNotifierProvider(widget.chatId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleOnlyAdmins(bool value) async {
    await ref.read(groupsRepositoryProvider).updateGroup(widget.chatId, onlyAdminsCanPost: value);
    if (mounted) ref.invalidate(chatDetailNotifierProvider(widget.chatId));
  }

  Future<void> _addParticipants(Set<String> existingIds) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
          title: 'Add participants',
          multiSelect: true,
          excludeUserIds: existingIds,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final ids = (result as List).map((c) => c.contactUser!.id as String).toList();
    if (ids.isEmpty) return;
    await ref.read(groupsRepositoryProvider).addParticipants(widget.chatId, ids);
    if (mounted) ref.invalidate(chatDetailNotifierProvider(widget.chatId));
  }

  void _showParticipantActions(ChatParticipant participant, bool amIAdmin) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(participant.isAdmin ? Icons.remove_moderator_outlined : Icons.admin_panel_settings_outlined),
              title: Text(participant.isAdmin ? 'Remove as admin' : 'Make group admin'),
              onTap: () async {
                Navigator.pop(ctx);
                if (!mounted) return;
                await ref
                    .read(groupsRepositoryProvider)
                    .setParticipantRole(widget.chatId, participant.userId, isAdmin: !participant.isAdmin);
                if (mounted) ref.invalidate(chatDetailNotifierProvider(widget.chatId));
              },
            ),
            ListTile(
              leading: Icon(Icons.person_remove_outlined, color: Theme.of(context).colorScheme.error),
              title: Text('Remove from group', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                Navigator.pop(ctx);
                if (!mounted) return;
                await ref.read(groupsRepositoryProvider).removeParticipant(widget.chatId, participant.userId);
                if (mounted) ref.invalidate(chatDetailNotifierProvider(widget.chatId));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Leave group',
      message: 'You will no longer receive messages from this group.',
      confirmLabel: 'Leave',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(groupsRepositoryProvider).leaveGroup(widget.chatId);
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatDetailNotifierProvider(widget.chatId));
    final myUserId = ref.watch(currentUserIdProvider);
    final chat = state.chat;
    final group = chat?.group;
    final me = chat?.participants.where((p) => p.userId == myUserId).firstOrNull;
    final amIAdmin = me?.isAdmin ?? false;

    if (chat == null || group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Group info')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: amIAdmin ? _changePhoto : null,
              child: Stack(
                children: [
                  AppAvatar(photoUrl: group.groupImageUrl, initials: group.groupName.substring(0, 1).toUpperCase(), size: 96),
                  if (amIAdmin)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text(group.groupName, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            trailing: amIAdmin ? const Icon(Icons.edit_outlined) : null,
            onTap: amIAdmin ? () => _renameGroup(group.groupName) : null,
          ),
          if (amIAdmin)
            SwitchListTile(
              title: const Text('Only admins can send messages'),
              value: group.onlyAdminsCanPost,
              onChanged: _toggleOnlyAdmins,
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${chat.participants.length} participants', style: Theme.of(context).textTheme.titleSmall),
                if (amIAdmin)
                  TextButton.icon(
                    onPressed: () => _addParticipants(chat.participants.map((p) => p.userId).toSet()),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Add'),
                  ),
              ],
            ),
          ),
          ...chat.participants.map((p) {
            return ListTile(
              leading: AppAvatar(photoUrl: p.user.photoUrl, initials: p.user.initials),
              title: Text(p.user.displayName),
              trailing: p.isAdmin
                  ? Text('Admin', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12))
                  : null,
              onTap: (amIAdmin && p.userId != myUserId) ? () => _showParticipantActions(p, amIAdmin) : null,
            );
          }),
          const Divider(),
          ListTile(
            leading: Icon(Icons.exit_to_app, color: Theme.of(context).colorScheme.error),
            title: Text('Leave group', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: _leaveGroup,
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        ],
      ),
    );
  }
}
