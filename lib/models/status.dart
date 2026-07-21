import '../core/utils/json_utils.dart';
import '../core/utils/url_utils.dart';
import 'user.dart';

enum StatusType { text, image, video }

StatusType statusTypeFromString(String? raw) {
  switch (raw) {
    case 'image':
      return StatusType.image;
    case 'video':
      return StatusType.video;
    default:
      return StatusType.text;
  }
}

class StatusItem {
  const StatusItem({
    required this.id,
    required this.userId,
    this.user,
    required this.type,
    this.content,
    this.mediaUrl,
    this.backgroundColor,
    required this.createdAt,
    this.viewedByMe = false,
    this.viewCount = 0,
  });

  final String id;
  final String userId;
  final AppUser? user;
  final StatusType type;
  final String? content;
  final String? mediaUrl;
  final String? backgroundColor;
  final DateTime createdAt;
  final bool viewedByMe;
  final int viewCount;

  Duration get displayDuration =>
      type == StatusType.video ? const Duration(seconds: 15) : const Duration(seconds: 5);

  factory StatusItem.fromJson(Map<String, dynamic> json) {
    final type = statusTypeFromString(asStringOrNull(json['type']));
    final rawContent = asStringOrNull(json['content']);
    // The backend has no separate media_url column — for an image/video
    // status it stores the uploaded asset's URL directly in `content` (and
    // overwrites any caption when there's a file), the same convention the
    // web client's status viewer relies on. `content` is only ever a real
    // caption for a text status.
    final isMedia = type == StatusType.image || type == StatusType.video;
    return StatusItem(
      id: asString(json['id']),
      userId: asString(json['user_id']),
      user: json['user'] is Map ? AppUser.fromJson(asMap(json['user'])) : null,
      type: type,
      content: isMedia ? null : rawContent,
      mediaUrl: isMedia ? normalizeMediaUrl(rawContent) : null,
      backgroundColor: asStringOrNull(json['background_color']),
      createdAt: asDateTimeOrNull(json['created_at']) ?? DateTime.now(),
      viewedByMe: asBool(json['viewed_by_me']),
      viewCount: asInt(json['view_count'] ?? json['views_count']),
    );
  }
}

/// One poster + all their non-expired statuses, as `GET /statuses` groups them.
class StatusGroup {
  const StatusGroup({required this.userId, required this.user, required this.statuses});

  final String userId;
  final AppUser user;
  final List<StatusItem> statuses;

  bool get allViewed => statuses.every((s) => s.viewedByMe);

  /// The backend groups statuses with Laravel's `Collection::groupBy('user_id')`,
  /// which serializes as a JSON object keyed by user ID —
  /// `{ "<uuid>": [status, status, ...] }` — not an array of
  /// `{user_id, user, statuses}` wrapper objects. Each raw status already
  /// embeds its poster under `user`, so that's reused here rather than
  /// expecting a separate top-level `user` field per group.
  static List<StatusGroup> listFromGroupedJson(dynamic raw) {
    if (raw is! Map) return const [];
    final groups = <StatusGroup>[];
    for (final entry in raw.entries) {
      final items = asList(entry.value, (e) => StatusItem.fromJson(asMap(e)));
      final user = items.isNotEmpty ? items.first.user : null;
      if (user == null) continue;
      groups.add(StatusGroup(userId: asString(entry.key), user: user, statuses: items));
    }
    return groups;
  }
}
