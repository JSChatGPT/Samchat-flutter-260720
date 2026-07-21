import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../models/contact.dart';
import '../../../onboarding_contacts/application/contacts_sync_notifier.dart';

/// Picks a raw device contact (any phone contact, not just SamChat users) to
/// prefill the SMS compose "To" field with — pops with the selected phone
/// number, or null if the user backs out.
class SmsContactPickerScreen extends ConsumerStatefulWidget {
  const SmsContactPickerScreen({super.key});

  @override
  ConsumerState<SmsContactPickerScreen> createState() => _SmsContactPickerScreenState();
}

class _SmsContactPickerScreenState extends ConsumerState<SmsContactPickerScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<DeviceContact>? _contacts;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _permissionDenied = false;
      _contacts = null;
    });
    final repo = ref.read(contactsRepositoryProvider);
    final granted = await repo.requestDevicePermission();
    if (!mounted) return;
    if (!granted) {
      setState(() => _permissionDenied = true);
      return;
    }
    final contacts = await repo.readDeviceContacts();
    contacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) setState(() => _contacts = contacts);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose contact'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_permissionDenied) {
      return EmptyStateWidget(
        icon: Icons.contacts_outlined,
        title: 'Contacts permission needed',
        message: 'Allow contacts access to pick a recipient, or go back and type their number instead.',
        action: ElevatedButton(onPressed: _load, child: const Text('Grant access')),
      );
    }
    if (_contacts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _contacts!.where((c) {
      if (_query.isEmpty) return true;
      return c.name.toLowerCase().contains(_query) || c.phoneNumber.contains(_query);
    }).toList();
    if (filtered.isEmpty) {
      return const EmptyStateWidget(icon: Icons.person_search_outlined, title: 'No contacts found');
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final contact = filtered[index];
        return ListTile(
          leading: AppAvatar(initials: contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?'),
          title: Text(contact.name),
          subtitle: Text(contact.phoneNumber),
          onTap: () => Navigator.pop(context, contact.phoneNumber),
        );
      },
    );
  }
}
