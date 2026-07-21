import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../models/call.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../application/call_notifier.dart';

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear call history',
      message: 'This removes all calls from your history.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (confirmed) {
      await ref.read(callsRepositoryProvider).clearHistory();
      ref.invalidate(callHistoryProvider);
    }
  }

  void _redial(BuildContext context, CallRecord call, String myUserId) {
    if (call.isGroupCall) {
      if (call.chatId == null) return;
      context.pushNamed(
        RouteNames.outgoingCall,
        extra: {'chatId': call.chatId, 'video': call.callType == CallType.video},
      );
      return;
    }
    final counterpart = call.counterpart(myUserId);
    if (counterpart == null) return;
    context.pushNamed(
      RouteNames.outgoingCall,
      extra: {'receiverId': counterpart.id, 'video': call.callType == CallType.video},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUserId = ref.watch(currentUserIdProvider);
    final historyAsync = ref.watch(callHistoryProvider);
    return Scaffold(
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateWidget(
          message: '$error',
          onRetry: () => ref.invalidate(callHistoryProvider),
        ),
        data: (calls) {
          if (calls.isEmpty) {
            return const EmptyStateWidget(icon: Icons.call_outlined, title: 'No calls yet');
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(callHistoryProvider.future),
            child: ListView.builder(
              itemCount: calls.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _clearAll(context, ref),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Clear all'),
                    ),
                  );
                }
                final call = calls[index - 1];
                return _buildCallTile(context, call, myUserId);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCallTile(BuildContext context, CallRecord call, String myUserId) {
    final title = call.title(myUserId);
    final photo = call.photoUrl(myUserId);
    final outgoing = call.callerId == myUserId;
    final missed = !outgoing && call.acceptedAt == null && call.endedAt != null;
    return ListTile(
      leading: AppAvatar(photoUrl: photo, initials: title.isNotEmpty ? title.substring(0, 1).toUpperCase() : '?'),
      title: Text(title),
      subtitle: Row(
        children: [
          Icon(
            outgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
            size: 14,
            color: missed ? Theme.of(context).colorScheme.error : null,
          ),
          const SizedBox(width: 4),
          Text(call.startedAt != null ? _relative(call.startedAt!) : ''),
        ],
      ),
      trailing: IconButton(
        icon: Icon(call.callType == CallType.video ? Icons.videocam_outlined : Icons.call_outlined),
        onPressed: () => _redial(context, call, myUserId),
      ),
      onTap: () => _redial(context, call, myUserId),
    );
  }

  String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
