import '../core/utils/json_utils.dart';
import 'user.dart';

class SavedContact {
  const SavedContact({
    required this.id,
    required this.customName,
    this.contactUser,
  });

  final String id;
  final String customName;
  final AppUser? contactUser;

  factory SavedContact.fromJson(Map<String, dynamic> json) {
    return SavedContact(
      id: asString(json['id']),
      customName: asString(json['custom_name']),
      contactUser:
          json['contact_user'] is Map ? AppUser.fromJson(asMap(json['contact_user'])) : null,
    );
  }
}

/// A raw entry read from the device address book, before syncing.
class DeviceContact {
  const DeviceContact({required this.name, required this.phoneNumber});

  final String name;
  final String phoneNumber;

  Map<String, dynamic> toSyncJson() => {'phone_number': phoneNumber, 'name': name};
}
