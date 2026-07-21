import '../core/utils/json_utils.dart';
import 'user.dart';

enum MeetingCallType { audio, video }

MeetingCallType meetingCallTypeFromString(String? raw) =>
    raw == 'audio' ? MeetingCallType.audio : MeetingCallType.video;

enum InviteeStatus { invited, accepted, declined }

InviteeStatus inviteeStatusFromString(String? raw) {
  switch (raw) {
    case 'accepted':
      return InviteeStatus.accepted;
    case 'declined':
      return InviteeStatus.declined;
    default:
      return InviteeStatus.invited;
  }
}

class MeetingInviteeRecord {
  const MeetingInviteeRecord({required this.userId, required this.user, required this.status});

  final String userId;
  final AppUser user;
  final InviteeStatus status;

  factory MeetingInviteeRecord.fromJson(Map<String, dynamic> json) {
    return MeetingInviteeRecord(
      userId: asString(json['user_id']),
      user: AppUser.fromJson(asMap(json['user'])),
      status: inviteeStatusFromString(asStringOrNull(json['status'])),
    );
  }
}

class Meeting {
  const Meeting({
    required this.id,
    required this.hostId,
    this.host,
    this.chatId,
    required this.title,
    this.description,
    required this.callType,
    required this.scheduledAt,
    required this.durationMinutes,
    this.startedAt,
    this.invitees = const [],
  });

  final String id;
  final String hostId;
  final AppUser? host;
  final String? chatId;
  final String title;
  final String? description;
  final MeetingCallType callType;
  final DateTime scheduledAt;
  final int durationMinutes;
  final DateTime? startedAt;
  final List<MeetingInviteeRecord> invitees;

  bool get hasStarted => startedAt != null;
  DateTime get endsAt => scheduledAt.add(Duration(minutes: durationMinutes));
  bool get isPast => DateTime.now().isAfter(endsAt);

  /// Whether the "Join" action should be enabled — from 5 minutes before the
  /// scheduled time until the meeting's scheduled window ends.
  bool get isJoinable {
    final now = DateTime.now();
    return now.isAfter(scheduledAt.subtract(const Duration(minutes: 5))) && !isPast;
  }

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: asString(json['id']),
      hostId: asString(json['host_id']),
      host: json['host'] is Map ? AppUser.fromJson(asMap(json['host'])) : null,
      chatId: asStringOrNull(json['chat_id']),
      title: asString(json['title']),
      description: asStringOrNull(json['description']),
      callType: meetingCallTypeFromString(asStringOrNull(json['call_type'])),
      scheduledAt: asDateTimeOrNull(json['scheduled_at']) ?? DateTime.now(),
      durationMinutes: asInt(json['duration_minutes'], fallback: 30),
      startedAt: asDateTimeOrNull(json['started_at']),
      invitees: asList(json['invitees'], (e) => MeetingInviteeRecord.fromJson(asMap(e))),
    );
  }
}
