import '../core/utils/json_utils.dart';
import '../core/utils/url_utils.dart';

class AppUser {
  const AppUser({
    required this.id,
    this.firstName,
    this.middleName,
    this.lastName,
    this.username,
    this.phoneNumber,
    this.email,
    this.aboutStatus,
    this.photoUrl,
    this.isBlocked = false,
    this.lastSeenAt,
    this.savedName,
  });

  final String id;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? username;
  final String? phoneNumber;
  final String? email;
  final String? aboutStatus;
  final String? photoUrl;
  final bool isBlocked;
  final DateTime? lastSeenAt;
  final String? savedName;

  String get fullName =>
      [firstName, middleName, lastName].where((e) => e != null && e.isNotEmpty).join(' ');

  /// The single canonical name to render anywhere a user's identity is
  /// shown — always prefer the caller's address-book override when present.
  String get displayName {
    if (savedName != null && savedName!.trim().isNotEmpty) return savedName!;
    final name = fullName;
    if (name.trim().isNotEmpty) return name;
    if (username != null && username!.isNotEmpty) return username!;
    return phoneNumber ?? 'Unknown';
  }

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length < 2 ? parts.first.length : 2).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  bool get isOnlineNow =>
      lastSeenAt != null && DateTime.now().difference(lastSeenAt!.toLocal()).inMinutes < 2;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: asString(json['id']),
      firstName: asStringOrNull(json['first_name']),
      middleName: asStringOrNull(json['middle_name']),
      lastName: asStringOrNull(json['last_name']),
      username: asStringOrNull(json['username']),
      phoneNumber: asStringOrNull(json['phone_number']),
      email: asStringOrNull(json['email']),
      aboutStatus: asStringOrNull(json['about_status']),
      photoUrl: normalizeMediaUrl(asStringOrNull(json['photo_url'])),
      isBlocked: asBool(json['is_blocked']),
      lastSeenAt: asDateTimeOrNull(json['last_seen_at']),
      savedName: asStringOrNull(json['saved_name']),
    );
  }

  AppUser copyWith({
    String? photoUrl,
    String? aboutStatus,
    DateTime? lastSeenAt,
    String? savedName,
  }) {
    return AppUser(
      id: id,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      username: username,
      phoneNumber: phoneNumber,
      email: email,
      aboutStatus: aboutStatus ?? this.aboutStatus,
      photoUrl: photoUrl ?? this.photoUrl,
      isBlocked: isBlocked,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      savedName: savedName ?? this.savedName,
    );
  }
}
