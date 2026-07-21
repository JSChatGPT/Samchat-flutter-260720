import 'package:flutter/services.dart';

/// Wraps the native `samchat/contacts_link` platform channel — see
/// android/.../contacts/ContactLinkPlugin.kt. Gives each SamChat friend a
/// "connected apps" row on their device-contact detail page.
class ContactLinkChannel {
  static const _channel = MethodChannel('samchat/contacts_link');

  /// Each entry: {"userId", "phoneNumber", "displayName"}.
  static Future<void> pushContacts(List<Map<String, String>> contacts) {
    return _channel.invokeMethod('pushContacts', contacts);
  }
}
