import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../application/statuses_notifier.dart';

class StatusListScreen extends ConsumerWidget {
  const StatusListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statusesNotifierProvider);
    final me = ref.watch(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'status_fab',
        onPressed: () => context.pushNamed(RouteNames.statusCreate),
        child: const Icon(Icons.camera_alt_rounded),
      ),
      body: _buildBody(context, ref, state, me?.id ?? '', me?.photoUrl, me?.initials ?? '?', scheme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    StatusesState state,
    String myUserId,
    String? myPhotoUrl,
    String myInitials,
    ColorScheme scheme,
  ) {
    if (state.loadState == StatusesLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.loadState == StatusesLoadState.error) {
      return ErrorStateWidget(
        message: state.error ?? 'Could not load statuses',
        onRetry: () => ref.read(statusesNotifierProvider.notifier).refresh(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(statusesNotifierProvider.notifier).refresh(),
      child: ListView(
        children: [
          ListTile(
            leading: Stack(
              children: [
                AppAvatar(photoUrl: myPhotoUrl, initials: myInitials, size: 52),
                if (state.myStatuses.isEmpty)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
            title: const Text('My status'),
            subtitle: Text(state.myStatuses.isEmpty ? 'Tap to add status update' : '${state.myStatuses.length} update(s) · tap to view'),
            onTap: () {
              if (state.myStatuses.isEmpty) {
                context.pushNamed(RouteNames.statusCreate);
              } else {
                context.pushNamed(
                  RouteNames.statusViewer,
                  pathParameters: {'userId': myUserId},
                  extra: state.myStatuses,
                );
              }
            },
          ),
          if (state.otherGroups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Recent updates', style: Theme.of(context).textTheme.titleSmall),
            ),
            ...state.otherGroups.map((group) {
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: group.allViewed ? scheme.outlineVariant : scheme.primary, width: 2.5),
                  ),
                  child: AppAvatar(photoUrl: group.user.photoUrl, initials: group.user.initials, size: 48),
                ),
                title: Text(group.user.displayName),
                subtitle: Text(_relativeTime(group.statuses.last.createdAt)),
                onTap: () => context.pushNamed(
                  RouteNames.statusViewer,
                  pathParameters: {'userId': group.userId},
                  extra: group.statuses,
                ),
              );
            }),
          ] else if (state.myStatuses.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: EmptyStateWidget(
                icon: Icons.donut_large_outlined,
                title: 'No status updates',
                message: 'Statuses from your contacts will show up here.',
              ),
            ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
