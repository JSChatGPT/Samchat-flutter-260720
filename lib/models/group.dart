import '../core/utils/json_utils.dart';
import '../core/utils/url_utils.dart';

class ChatGroup {
  const ChatGroup({
    required this.id,
    required this.groupName,
    this.groupImageUrl,
    this.onlyAdminsCanPost = false,
    this.createdBy,
  });

  final String id;
  final String groupName;
  final String? groupImageUrl;
  final bool onlyAdminsCanPost;
  final String? createdBy;

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: asStringOrNull(json['id']) ?? asString(json['chat_id']),
      groupName: asString(json['group_name']),
      groupImageUrl: normalizeMediaUrl(asStringOrNull(json['group_image_url'])),
      onlyAdminsCanPost: asBool(json['only_admins_can_post']),
      createdBy: asStringOrNull(json['created_by'] ?? json['created_by_user_id']),
    );
  }

  /// Mirrors [fromJson] — see AppUser.toJson for why.
  Map<String, dynamic> toJson() => {
        'id': id,
        'group_name': groupName,
        'group_image_url': groupImageUrl,
        'only_admins_can_post': onlyAdminsCanPost,
        'created_by': createdBy,
      };
}
