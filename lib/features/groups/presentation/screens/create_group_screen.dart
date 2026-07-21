import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../models/contact.dart';
import '../../../onboarding_contacts/presentation/screens/contact_picker_screen.dart';
import '../../data/groups_repository.dart';

final groupsRepositoryProvider =
    Provider((ref) => GroupsRepository(ref.watch(dioProvider), ref.watch(e2eeServiceProvider)));

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  List<SavedContact> _participants = [];
  bool _creating = false;
  bool _pickedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickParticipants());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickParticipants() async {
    final result = await Navigator.of(context).push<List<SavedContact>>(
      MaterialPageRoute(
        builder: (_) => const ContactPickerScreen(title: 'Add participants', multiSelect: true),
      ),
    );
    _pickedOnce = true;
    if (result == null || result.isEmpty) {
      if (mounted) context.pop();
      return;
    }
    setState(() => _participants = result);
  }

  Future<void> _pickMoreParticipants() async {
    final existingIds = _participants.map((c) => c.contactUser!.id).toSet();
    final result = await Navigator.of(context).push<List<SavedContact>>(
      MaterialPageRoute(
        builder: (_) => ContactPickerScreen(
          title: 'Add participants',
          multiSelect: true,
          excludeUserIds: existingIds,
        ),
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    setState(() => _participants = [..._participants, ...result]);
  }

  void _removeParticipant(SavedContact contact) {
    setState(() => _participants.removeWhere((c) => c.contactUser!.id == contact.contactUser!.id));
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _participants.isEmpty) return;
    setState(() => _creating = true);
    try {
      final chat = await ref.read(groupsRepositoryProvider).createGroup(
            groupName: name,
            userIds: _participants.map((c) => c.contactUser!.id).toList(),
          );
      if (mounted) {
        context.pushReplacementNamed(RouteNames.chatDetail, pathParameters: {'chatId': chat.id});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create group: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_pickedOnce) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final scheme = Theme.of(context).colorScheme;
    final canCreate = !_creating && _nameController.text.trim().isNotEmpty && _participants.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                '${_participants.length} ${_participants.length == 1 ? 'participant' : 'participants'}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _AddParticipantChip(onTap: _pickMoreParticipants),
                    for (final contact in _participants)
                      _ParticipantChip(
                        label: contact.customName.isNotEmpty ? contact.customName : contact.contactUser!.displayName,
                        photoUrl: contact.contactUser!.photoUrl,
                        initials: contact.contactUser!.initials,
                        onRemove: () => _removeParticipant(contact),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canCreate ? _create : null,
                  child: _creating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create group'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantChip extends StatelessWidget {
  const _ParticipantChip({
    required this.label,
    required this.photoUrl,
    required this.initials,
    required this.onRemove,
  });

  final String label;
  final String? photoUrl;
  final String initials;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppAvatar(photoUrl: photoUrl, initials: initials, size: 60),
              Positioned(
                top: -2,
                right: -2,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: scheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AddParticipantChip extends StatelessWidget {
  const _AddParticipantChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
                border: Border.all(color: scheme.primary.withValues(alpha: 0.3), style: BorderStyle.solid),
              ),
              child: Icon(Icons.add_rounded, color: scheme.primary, size: 28),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add',
            maxLines: 1,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.primary),
          ),
        ],
      ),
    );
  }
}
