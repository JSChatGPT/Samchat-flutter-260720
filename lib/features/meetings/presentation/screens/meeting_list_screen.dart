import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../models/meeting.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../application/meetings_notifier.dart';

class MeetingListScreen extends ConsumerWidget {
  const MeetingListScreen({super.key});

  Future<void> _join(BuildContext context, WidgetRef ref, Meeting meeting) async {
    final chatId = meeting.chatId;
    if (chatId == null) return;
    try {
      // Bookkeeping (marks started_at) — the actual call goes through the
      // same outgoing-call route every other group call uses, so there's
      // only one place in the app that creates a Call and rings people.
      await ref.read(meetingsNotifierProvider.notifier).start(meeting.id);
      if (!context.mounted) return;
      context.pushNamed(
        RouteNames.outgoingCall,
        extra: {'chatId': chatId, 'video': meeting.callType == MeetingCallType.video},
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start meeting: $e')));
      }
    }
  }

  Future<void> _addToCalendar(BuildContext context, WidgetRef ref, Meeting meeting) async {
    try {
      final bytes = await ref.read(meetingsRepositoryProvider).downloadIcs(meeting.id);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/meeting-${meeting.id}.ics');
      await file.writeAsBytes(bytes);
      await launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export calendar file: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meetingsNotifierProvider);
    final myUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meetings')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'meetings_fab',
        onPressed: () => context.pushNamed(RouteNames.scheduleMeeting),
        child: const Icon(Icons.add),
      ),
      body: switch (state.status) {
        MeetingsLoadStatus.loading => const Center(child: CircularProgressIndicator()),
        MeetingsLoadStatus.error => ErrorStateWidget(
            message: state.error ?? 'Could not load meetings',
            onRetry: () => ref.read(meetingsNotifierProvider.notifier).refresh(),
          ),
        MeetingsLoadStatus.loaded => state.meetings.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.event_outlined,
                title: 'No meetings scheduled',
                message: 'Tap + to schedule a meeting with your contacts.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.read(meetingsNotifierProvider.notifier).refresh(),
                child: ListView.separated(
                  itemCount: state.meetings.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
                  itemBuilder: (context, index) => _MeetingTile(
                    meeting: state.meetings[index],
                    myUserId: myUserId,
                    onJoin: () => _join(context, ref, state.meetings[index]),
                    onAccept: () => ref.read(meetingsNotifierProvider.notifier).respond(state.meetings[index].id, accept: true),
                    onDecline: () => ref.read(meetingsNotifierProvider.notifier).respond(state.meetings[index].id, accept: false),
                    onAddToCalendar: () => _addToCalendar(context, ref, state.meetings[index]),
                  ),
                ),
              ),
      },
    );
  }
}

class _MeetingTile extends StatelessWidget {
  const _MeetingTile({
    required this.meeting,
    required this.myUserId,
    required this.onJoin,
    required this.onAccept,
    required this.onDecline,
    required this.onAddToCalendar,
  });

  final Meeting meeting;
  final String myUserId;
  final VoidCallback onJoin;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onAddToCalendar;

  @override
  Widget build(BuildContext context) {
    final isHost = meeting.hostId == myUserId;
    final myInvite = meeting.invitees.where((i) => i.userId == myUserId).firstOrNull;
    final needsResponse = !isHost && myInvite?.status == InviteeStatus.invited;
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: AppAvatar(
        photoUrl: meeting.host?.photoUrl,
        initials: meeting.host?.initials ?? '?',
        size: 48,
      ),
      title: Text(meeting.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_formatWhen(meeting.scheduledAt)} · ${meeting.durationMinutes} min'
        '${meeting.isPast ? ' · Ended' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: needsResponse
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: Icon(Icons.check_circle, color: scheme.primary), onPressed: onAccept),
                IconButton(icon: Icon(Icons.cancel_outlined, color: scheme.error), onPressed: onDecline),
              ],
            )
          : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'join') onJoin();
                if (value == 'calendar') onAddToCalendar();
              },
              itemBuilder: (context) => [
                if (meeting.isJoinable) const PopupMenuItem(value: 'join', child: Text('Join')),
                const PopupMenuItem(value: 'calendar', child: Text('Add to calendar')),
              ],
            ),
      onTap: meeting.isJoinable ? onJoin : null,
    );
  }

  String _formatWhen(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    final time = TimeOfDay.fromDateTime(local).format24Hour();
    return isToday ? 'Today, $time' : '${local.day}/${local.month}/${local.year}, $time';
  }
}

extension on TimeOfDay {
  String format24Hour() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
