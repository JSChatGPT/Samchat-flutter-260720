import 'package:dio/dio.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/utils/json_utils.dart';
import '../../../models/contact.dart';

class ContactsRepository {
  ContactsRepository(this._dio);

  final Dio _dio;

  Future<bool> requestDevicePermission() => FlutterContacts.requestPermission(readonly: true);

  Future<List<DeviceContact>> readDeviceContacts() async {
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final result = <DeviceContact>[];
    for (final c in contacts) {
      final name = c.displayName.trim();
      if (name.isEmpty) continue;
      for (final phone in c.phones) {
        final number = phone.number.trim();
        if (number.isEmpty) continue;
        result.add(DeviceContact(name: name, phoneNumber: number));
      }
    }
    return result;
  }

  static final _contactErrorIndex = RegExp(r'^contacts\.(\d+)\.');

  /// Bulk phone-book import — the primary mobile onboarding flow.
  ///
  /// The backend validates every row and 422s the *whole* batch over a
  /// single malformed one (e.g. a phone-book entry whose number turned out
  /// empty after normalization, or some other quirk client-side filtering
  /// didn't anticipate) — rather than lose the entire sync over one bad row,
  /// drop whatever index(es) the 422 flags and retry once.
  Future<List<SavedContact>> syncContacts(List<DeviceContact> contacts) async {
    var payload = contacts;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _dio.post(Endpoints.contactsSync, data: {
          'contacts': payload.map((c) => c.toSyncJson()).toList(),
        });
        return asList(res.data['contacts'], (e) => SavedContact.fromJson(asMap(e)));
      } on DioException catch (e) {
        final badIndexes = _badContactIndexes(e);
        if (attempt == 0 && badIndexes.isNotEmpty) {
          payload = [
            for (var i = 0; i < payload.length; i++)
              if (!badIndexes.contains(i)) payload[i],
          ];
          continue;
        }
        throw ApiException.fromDioError(e);
      }
    }
    throw ApiException(message: 'Could not sync contacts.');
  }

  Set<int> _badContactIndexes(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return {};
    final errors = data['errors'];
    if (errors is! Map) return {};
    final indexes = <int>{};
    for (final key in errors.keys) {
      final match = _contactErrorIndex.firstMatch(key.toString());
      if (match != null) indexes.add(int.parse(match.group(1)!));
    }
    return indexes;
  }

  Future<List<SavedContact>> getSavedContacts() async {
    try {
      final res = await _dio.get(Endpoints.contacts);
      final data = res.data is List ? res.data : res.data['contacts'];
      return asList(data, (e) => SavedContact.fromJson(asMap(e)));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> saveContact({required String contactUserId, required String customName}) async {
    try {
      await _dio.post(Endpoints.contacts, data: {
        'contact_user_id': contactUserId,
        'custom_name': customName,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> renameContact({required String id, required String customName}) async {
    try {
      await _dio.put(Endpoints.contact(id), data: {'custom_name': customName});
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteContact(String id) async {
    try {
      await _dio.delete(Endpoints.contact(id));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
