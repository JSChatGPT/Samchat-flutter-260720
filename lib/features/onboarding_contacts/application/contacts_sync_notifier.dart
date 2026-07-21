import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/phone_number.dart' as intl_phone;

import '../../../core/api/api_exception.dart';
import '../../../core/native/contact_link_channel.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/local_prefs_service.dart';
import '../../../models/contact.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/contacts_repository.dart';

enum ContactsSyncStatus { idle, permissionDenied, syncing, synced, error }

class ContactsSyncState {
  const ContactsSyncState({
    this.status = ContactsSyncStatus.idle,
    this.contacts = const [],
    this.notOnApp = const [],
    this.error,
  });

  final ContactsSyncStatus status;
  final List<SavedContact> contacts;

  /// Device-contact phone numbers submitted to `/contacts/sync` that came
  /// back unmatched — not yet on SamChat, so the picker offers to invite
  /// them instead of starting a chat.
  final List<DeviceContact> notOnApp;
  final String? error;

  ContactsSyncState copyWith({
    ContactsSyncStatus? status,
    List<SavedContact>? contacts,
    List<DeviceContact>? notOnApp,
    String? error,
  }) {
    return ContactsSyncState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      notOnApp: notOnApp ?? this.notOnApp,
      error: error,
    );
  }
}

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(ref.watch(dioProvider));
});

final contactsSyncNotifierProvider =
    StateNotifierProvider<ContactsSyncNotifier, ContactsSyncState>((ref) {
  return ContactsSyncNotifier(
    repository: ref.watch(contactsRepositoryProvider),
    prefs: ref.watch(localPrefsServiceProvider),
    myPhoneNumber: ref.watch(authNotifierProvider).currentUser?.phoneNumber,
  );
});

class ContactsSyncNotifier extends StateNotifier<ContactsSyncState> {
  ContactsSyncNotifier({required this.repository, required this.prefs, this.myPhoneNumber})
      : super(const ContactsSyncState()) {
    // Re-sync (not just reload the saved list) so `notOnApp` — which isn't
    // persisted between app sessions — is populated as soon as the picker
    // opens, not only after a manual pull-to-refresh.
    if (prefs.contactsSynced) {
      syncFromDevice();
    }
  }

  final ContactsRepository repository;
  final LocalPrefsService prefs;

  /// This user's own E.164 phone number, used only to recover the dial code
  /// for converting local-format device contacts (see [_toE164]).
  final String? myPhoneNumber;

  Future<void> syncFromDevice() async {
    state = state.copyWith(status: ContactsSyncStatus.syncing);
    final granted = await repository.requestDevicePermission();
    if (!granted) {
      state = state.copyWith(status: ContactsSyncStatus.permissionDenied);
      return;
    }
    try {
      final dialCode = _dialCodeOf(myPhoneNumber);
      final deviceContacts = (await repository.readDeviceContacts())
          .map((c) => DeviceContact(name: c.name, phoneNumber: _toE164(c.phoneNumber, dialCode)))
          // A raw number with no digits at all (e.g. a label like "N/A", or
          // a lone "+") normalizes to something the backend's `required`
          // validation rejects as empty — drop those before syncing rather
          // than 422ing the whole batch.
          .where((c) => c.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty)
          .toList();
      final synced = await repository.syncContacts(deviceContacts);
      // The sync endpoint only echoes back contacts it matched to a SamChat
      // user — diff against the submitted list (same [^0-9+] normalization
      // the backend uses) to find who to offer an invite to instead.
      final matchedPhones = synced
          .map((c) => c.contactUser?.phoneNumber)
          .whereType<String>()
          .map(_normalizePhone)
          .toSet();
      final notOnApp = <String, DeviceContact>{};
      for (final contact in deviceContacts) {
        final normalized = _normalizePhone(contact.phoneNumber);
        if (normalized.isEmpty || matchedPhones.contains(normalized)) continue;
        notOnApp[normalized] = contact;
      }
      await prefs.setContactsSynced(true);
      state = state.copyWith(
        status: ContactsSyncStatus.synced,
        contacts: synced,
        notOnApp: notOnApp.values.toList(),
      );
      _pushContactLinks(synced);
    } on ApiException catch (e) {
      state = state.copyWith(status: ContactsSyncStatus.error, error: e.message);
    }
  }

  /// Best-effort: gives each matched SamChat friend a "connected apps" row
  /// on their device-contact page (Android only — see ContactLinkPlugin.kt).
  /// Never blocks or fails the sync itself.
  void _pushContactLinks(List<SavedContact> synced) {
    if (!Platform.isAndroid) return;
    final links = [
      for (final contact in synced)
        if (contact.contactUser?.phoneNumber != null)
          {
            'userId': contact.contactUser!.id,
            'phoneNumber': contact.contactUser!.phoneNumber!,
            'displayName': contact.customName.isNotEmpty ? contact.customName : contact.contactUser!.displayName,
          },
    ];
    if (links.isEmpty) return;
    ContactLinkChannel.pushContacts(links).catchError((_) {});
  }

  static String _normalizePhone(String raw) => raw.replaceAll(RegExp(r'[^0-9+]'), '');

  static String? _dialCodeOf(String? e164) {
    if (e164 == null || e164.isEmpty) return null;
    try {
      return intl_phone.PhoneNumber.getCountry(e164).dialCode;
    } catch (_) {
      return null;
    }
  }

  /// Phone contacts are very often saved in local format (a leading trunk
  /// `0`, no country code) — the backend's matching is a plain `[^0-9+]`
  /// strip-and-compare against the `+countrycode...` number a user registered
  /// with, so a local-format contact silently fails to match even when that
  /// person genuinely has an account. Converting to E.164 first (using this
  /// user's own dial code as the best guess) fixes both the sync match and
  /// the notOnApp diff below.
  static String _toE164(String raw, String? dialCode) {
    final stripped = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (stripped.startsWith('+')) return stripped;
    if (stripped.startsWith('00')) return '+${stripped.substring(2)}';
    // Some devices store contacts with the full country code but no
    // leading '+' (e.g. "260968793843") — treating that as a local trunk
    // number would double-prefix it to "+260260968793843". If the digits
    // already start with the dial code and are long enough to plausibly
    // contain a full subscriber number after it, just add the '+'.
    if (dialCode != null && dialCode.isNotEmpty && stripped.startsWith(dialCode) && stripped.length > dialCode.length + 6) {
      return '+$stripped';
    }
    if (dialCode == null) return stripped;
    final local = stripped.startsWith('0') ? stripped.substring(1) : stripped;
    if (local.isEmpty) return stripped;
    return '+$dialCode$local';
  }
}
