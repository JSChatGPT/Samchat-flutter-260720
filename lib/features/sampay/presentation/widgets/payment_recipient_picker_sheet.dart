import 'package:flutter/material.dart';

import '../../../../core/widgets/app_avatar.dart';
import '../../../../models/chat_participant.dart';

/// Bottom sheet letting the sender pick which group member to pay,
/// since a group (unlike a direct chat) has no single implicit recipient.
Future<ChatParticipant?> pickPaymentRecipient(
  BuildContext context, {
  required List<ChatParticipant> participants,
  required String myUserId,
}) {
  final others = participants.where((p) => p.userId != myUserId).toList();
  return showModalBottomSheet<ChatParticipant>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Choose recipient', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final p in others)
            ListTile(
              leading: AppAvatar(photoUrl: p.user.photoUrl, initials: p.user.initials),
              title: Text(p.user.displayName),
              onTap: () => Navigator.pop(ctx, p),
            ),
        ],
      ),
    ),
  );
}
