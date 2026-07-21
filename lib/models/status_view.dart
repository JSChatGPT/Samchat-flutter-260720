import '../core/utils/json_utils.dart';
import 'user.dart';

class StatusView {
  const StatusView({required this.id, required this.viewer, required this.viewedAt});

  final int id;
  final AppUser viewer;
  final DateTime viewedAt;

  factory StatusView.fromJson(Map<String, dynamic> json) {
    return StatusView(
      id: asInt(json['id']),
      viewer: AppUser.fromJson(asMap(json['viewer'] ?? json['user'])),
      viewedAt: asDateTimeOrNull(json['created_at']) ?? DateTime.now(),
    );
  }
}
