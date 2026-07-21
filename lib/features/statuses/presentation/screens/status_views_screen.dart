import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../models/status_view.dart';
import '../../application/statuses_notifier.dart';

class StatusViewsScreen extends ConsumerWidget {
  const StatusViewsScreen({super.key, required this.statusId});

  final String statusId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viewed by')),
      body: FutureBuilder<List<StatusView>>(
        future: ref.read(statusesRepositoryProvider).getViews(statusId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final views = snapshot.data ?? [];
          if (views.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.remove_red_eye_outlined,
              title: 'No views yet',
            );
          }
          return ListView.builder(
            itemCount: views.length,
            itemBuilder: (context, index) {
              final view = views[index];
              return ListTile(
                leading: AppAvatar(photoUrl: view.viewer.photoUrl, initials: view.viewer.initials),
                title: Text(view.viewer.displayName),
                trailing: Text(AppDateUtils.messageTime(view.viewedAt)),
              );
            },
          );
        },
      ),
    );
  }
}
