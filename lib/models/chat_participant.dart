import '../core/utils/json_utils.dart';
import 'user.dart';

class ChatParticipant {
  const ChatParticipant({
    required this.userId,
    required this.user,
    this.isAdmin = false,
  });

  final String userId;
  final AppUser user;
  final bool isAdmin;

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    final userJson = asMap(json['user']);
    return ChatParticipant(
      userId: asStringOrNull(json['user_id']) ?? asString(userJson['id']),
      user: AppUser.fromJson(userJson),
      isAdmin: asBool(json['is_admin']),
    );
  }

  /// Mirrors [fromJson] — see AppUser.toJson for why.
  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user': user.toJson(),
        'is_admin': isAdmin,
      };
}
