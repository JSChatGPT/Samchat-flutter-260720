import '../core/utils/json_utils.dart';
import 'group.dart';
import 'user.dart';

enum CallType { audio, video }

CallType callTypeFromString(String? raw) => raw == 'video' ? CallType.video : CallType.audio;

class CallRecord {
  const CallRecord({
    required this.id,
    this.chatId,
    required this.callerId,
    this.caller,
    this.receiverId,
    this.receiver,
    required this.callType,
    this.startedAt,
    this.endedAt,
    this.acceptedAt,
    this.group,
  });

  final String id;
  final String? chatId;
  final String callerId;
  final AppUser? caller;
  final String? receiverId;
  final AppUser? receiver;
  final CallType callType;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? acceptedAt;

  /// Only present for a group call (loaded from the call's `chat.group`
  /// relation) — used to show the group's name/photo instead of a single
  /// counterpart while ringing/connecting.
  final ChatGroup? group;

  bool get isActive => endedAt == null;
  bool get isGroupCall => receiverId == null;

  int get durationSeconds {
    if (acceptedAt == null) return 0;
    final end = endedAt ?? DateTime.now();
    return end.difference(acceptedAt!).inSeconds.clamp(0, 1 << 30);
  }

  AppUser? counterpart(String myUserId) => callerId == myUserId ? receiver : caller;

  /// What to show as the call's identity while ringing/connecting — the
  /// group's name for a group call, otherwise the 1:1 counterpart.
  String title(String myUserId) {
    if (isGroupCall) return group?.groupName ?? 'Group call';
    return counterpart(myUserId)?.displayName ?? 'Unknown';
  }

  String? photoUrl(String myUserId) {
    if (isGroupCall) return group?.groupImageUrl;
    return counterpart(myUserId)?.photoUrl;
  }

  factory CallRecord.fromJson(Map<String, dynamic> json) {
    final chatJson = json['chat'];
    final groupJson = chatJson is Map ? chatJson['group'] : null;
    return CallRecord(
      id: asString(json['id']),
      chatId: asStringOrNull(json['chat_id']),
      callerId: asString(json['caller_id']),
      caller: json['caller'] is Map ? AppUser.fromJson(asMap(json['caller'])) : null,
      receiverId: asStringOrNull(json['receiver_id']),
      receiver: json['receiver'] is Map ? AppUser.fromJson(asMap(json['receiver'])) : null,
      callType: callTypeFromString(asStringOrNull(json['call_type'])),
      startedAt: asDateTimeOrNull(json['started_at'] ?? json['created_at']),
      endedAt: asDateTimeOrNull(json['ended_at']),
      // The backend has no `accepted_at` column at all — it records the
      // answer time in `started_at` (set only inside CallController::accept,
      // left null until then). Reading the (nonexistent) `accepted_at` key
      // made this field always null, which made the in-call duration timer
      // permanently blank and made every answered-then-ended incoming call
      // misreport as "missed" in the call history list.
      acceptedAt: asDateTimeOrNull(json['started_at']),
      group: groupJson is Map ? ChatGroup.fromJson(asMap(groupJson)) : null,
    );
  }
}
