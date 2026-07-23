import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../models/contact.dart';
import '../../../chats/application/inbox_notifier.dart';
import '../../application/contacts_sync_notifier.dart';

class ContactPickerScreen extends ConsumerStatefulWidget {
  const ContactPickerScreen({
    super.key,
    this.title = 'New chat',
    this.excludeUserIds = const {},
    this.multiSelect = false,
  });

  final String title;
  final Set<String> excludeUserIds;

  /// When true, tapping a contact toggles a checkbox instead of immediately
  /// starting a chat; a "Next" FAB pops the screen with the selected
  /// [SavedContact] list — used by group creation and add-participants.
  final bool multiSelect;

  @override
  ConsumerState<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends ConsumerState<ContactPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _creatingChatFor = false;
  String? _pendingUserId;
  final Set<String> _selectedUserIds = {};
  final Map<String, SavedContact> _selectedContacts = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startChat(SavedContact contact) async {
    final userId = contact.contactUser?.id;
    if (userId == null) return;
    setState(() {
      _creatingChatFor = true;
      _pendingUserId = userId;
    });
    try {
      final repo = ref.read(chatsRepositoryProvider);
      final chat = await repo.createOrGetDirectChat(userId);
      if (!mounted) return;
      context.pushReplacementNamed(RouteNames.chatDetail, pathParameters: {'chatId': chat.id});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
      }
    } finally {
      if (mounted) setState(() => _creatingChatFor = false);
    }
  }

  static const _inviteMessage = "Hey! I'm using Samchat — download it so we can chat there.";

  Future<void> _invite(DeviceContact contact) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Invite via', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('SMS'),
              onTap: () {
                Navigator.pop(ctx);
                _launchInvite(Uri(
                  scheme: 'sms',
                  path: contact.phoneNumber,
                  queryParameters: {'body': _inviteMessage},
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(ctx);
                _launchInvite(
                  Uri.parse('https://wa.me/${contact.phoneNumber.replaceAll('+', '')}?text=${Uri.encodeComponent(_inviteMessage)}'),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              onTap: () {
                Navigator.pop(ctx);
                _launchInvite(Uri(scheme: 'mailto', queryParameters: {'body': _inviteMessage}));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchInvite(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
    final launched = await launchUrl(uri, mode: mode);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open messaging app')),
      );
    }
  }

  void _toggleSelected(SavedContact contact) {
    final userId = contact.contactUser?.id;
    if (userId == null) return;
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
        _selectedContacts.remove(userId);
      } else {
        _selectedUserIds.add(userId);
        _selectedContacts[userId] = contact;
      }
    });
  }

  String _labelFor(SavedContact c) => c.customName.isNotEmpty ? c.customName : c.contactUser!.displayName;

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(contactsSyncNotifierProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.multiSelect && _selectedUserIds.isNotEmpty
              ? '${_selectedUserIds.length} selected'
              : widget.title,
        ),
        actions: [
          IconButton(
            icon: syncState.status == ContactsSyncStatus.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh contacts',
            onPressed: syncState.status == ContactsSyncStatus.syncing
                ? null
                : () => ref.read(contactsSyncNotifierProvider.notifier).syncFromDevice(),
          ),
        ],
      ),
      floatingActionButton: widget.multiSelect && _selectedUserIds.isNotEmpty
          ? FloatingActionButton.extended(
              heroTag: 'contact_picker_fab',
              onPressed: () => Navigator.pop(context, _selectedContacts.values.toList()),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Next'),
            )
          : null,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
              decoration: InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(child: _buildBody(syncState, scheme)),
        ],
      ),
    );
  }

  Widget _buildBody(ContactsSyncState syncState, ColorScheme scheme) {
    if (syncState.status == ContactsSyncStatus.permissionDenied) {
      return EmptyStateWidget(
        icon: Icons.contacts_outlined,
        title: 'Contacts permission needed',
        message: 'Allow contacts access so Samchat can show you who\'s already here.',
        action: ElevatedButton(
          onPressed: () => ref.read(contactsSyncNotifierProvider.notifier).syncFromDevice(),
          child: const Text('Grant access'),
        ),
      );
    }
    if (syncState.status == ContactsSyncStatus.error) {
      return ErrorStateWidget(
        message: syncState.error ?? 'Something went wrong',
        onRetry: () => ref.read(contactsSyncNotifierProvider.notifier).syncFromDevice(),
      );
    }
    if (syncState.status == ContactsSyncStatus.idle) {
      return EmptyStateWidget(
        icon: Icons.people_outline,
        title: 'Find friends on Samchat',
        message: 'Sync your phone contacts to see who\'s already using Samchat.',
        action: ElevatedButton(
          onPressed: () => ref.read(contactsSyncNotifierProvider.notifier).syncFromDevice(),
          child: const Text('Sync contacts'),
        ),
      );
    }
    if (syncState.status == ContactsSyncStatus.syncing) {
      return const Center(child: CircularProgressIndicator());
    }

    final contacts = syncState.contacts.where((c) {
      if (c.contactUser == null) return false;
      if (widget.excludeUserIds.contains(c.contactUser!.id)) return false;
      if (_query.isEmpty) return true;
      return c.customName.toLowerCase().contains(_query) ||
          c.contactUser!.displayName.toLowerCase().contains(_query);
    }).toList()
      ..sort((a, b) => _labelFor(a).toLowerCase().compareTo(_labelFor(b).toLowerCase()));

    // Inviting a non-user doesn't make sense when picking existing members
    // for a group — only offer it in the "start a new chat" flow.
    final invitable = widget.multiSelect
        ? const <DeviceContact>[]
        : (syncState.notOnApp.where((c) {
            if (_query.isEmpty) return true;
            return c.name.toLowerCase().contains(_query);
          }).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

    if (contacts.isEmpty && invitable.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.person_search_outlined,
        title: 'No contacts found',
        message: 'No synced contacts match your search.',
      );
    }

    // Group matched contacts under A–Z section headers, like a phone's
    // native contacts app, instead of one long undifferentiated list.
    final rows = <_ContactRow>[];
    String? currentLetter;
    for (final contact in contacts) {
      final label = _labelFor(contact);
      final letter = label.isNotEmpty ? label[0].toUpperCase() : '#';
      if (letter != currentLetter) {
        rows.add(_ContactRow.section(letter));
        currentLetter = letter;
      }
      rows.add(_ContactRow.onApp(contact));
    }
    if (invitable.isNotEmpty) {
      rows.add(_ContactRow.section('Invite to Samchat', emphasized: true));
      rows.addAll(invitable.map(_ContactRow.invite));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(contactsSyncNotifierProvider.notifier).syncFromDevice(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row.section != null) {
            return Container(
              width: double.infinity,
              color: row.emphasized ? scheme.primary.withValues(alpha: 0.06) : scheme.surfaceContainerLow,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                row.section!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: row.emphasized ? scheme.primary : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            );
          }
          if (row.invite != null) {
            final deviceContact = row.invite!;
            return ListTile(
              leading: AppAvatar(initials: deviceContact.name.isNotEmpty ? deviceContact.name[0].toUpperCase() : '?'),
              title: Text(deviceContact.name),
              subtitle: Text(deviceContact.phoneNumber),
              trailing: TextButton(onPressed: () => _invite(deviceContact), child: const Text('Invite')),
            );
          }
          final contact = row.onApp!;
          final user = contact.contactUser!;
          final busy = _creatingChatFor && _pendingUserId == user.id;
          final selected = _selectedUserIds.contains(user.id);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: AppAvatar(photoUrl: user.photoUrl, initials: user.initials),
            title: Text(contact.customName.isNotEmpty ? contact.customName : user.displayName),
            subtitle: Text(
              user.aboutStatus?.isNotEmpty == true ? user.aboutStatus! : (user.phoneNumber ?? ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: widget.multiSelect
                ? Checkbox(value: selected, onChanged: (_) => _toggleSelected(contact))
                : (busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : null),
            onTap: _creatingChatFor
                ? null
                : (widget.multiSelect ? () => _toggleSelected(contact) : () => _startChat(contact)),
          );
        },
      ),
    );
  }
}

class _ContactRow {
  _ContactRow.onApp(SavedContact contact)
      : onApp = contact,
        section = null,
        emphasized = false,
        invite = null;
  _ContactRow.section(String title, {this.emphasized = false})
      : section = title,
        onApp = null,
        invite = null;
  _ContactRow.invite(DeviceContact contact)
      : invite = contact,
        onApp = null,
        section = null,
        emphasized = false;

  final SavedContact? onApp;
  final String? section;
  final bool emphasized;
  final DeviceContact? invite;
}
