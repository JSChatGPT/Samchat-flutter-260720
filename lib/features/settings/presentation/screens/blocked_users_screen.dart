import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../models/user.dart';
import '../../application/profile_notifier.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  late Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(profileRepositoryProvider).getBlockedUsers();
  }

  void _refresh() {
    setState(() => _future = ref.read(profileRepositoryProvider).getBlockedUsers());
  }

  Future<void> _unblock(AppUser user) async {
    await ref.read(profileRepositoryProvider).unblock(user.id);
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: FutureBuilder<List<AppUser>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const EmptyStateWidget(icon: Icons.block_outlined, title: 'No blocked users');
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: AppAvatar(photoUrl: user.photoUrl, initials: user.initials),
                title: Text(user.displayName),
                trailing: TextButton(onPressed: () => _unblock(user), child: const Text('Unblock')),
              );
            },
          );
        },
      ),
    );
  }
}
