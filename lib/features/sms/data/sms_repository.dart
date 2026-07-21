import 'package:flutter/services.dart';

import '../../../core/utils/json_utils.dart';
import '../../../models/sms_conversation.dart';
import '../../../models/sms_message.dart';

class SentSms {
  const SentSms({required this.id, required this.threadId});
  final String id;
  final String threadId;
}

/// Wraps the native `samchat/sms` platform channel — see
/// android/app/.../sms/SmsPlugin.kt. There's no Dart-only fallback: none of
/// this works until the app holds the Android "default SMS app" role.
class SmsRepository {
  static const _channel = MethodChannel('samchat/sms');
  static const _incoming = EventChannel('samchat/sms/incoming');

  Future<bool> isDefaultSmsApp() async {
    final result = await _channel.invokeMethod<bool>('isDefaultSmsApp');
    return result ?? false;
  }

  /// Launches the OS "set default SMS app" flow and resolves once the user
  /// returns, with whether the role was actually granted.
  Future<bool> requestDefaultSmsApp() async {
    final result = await _channel.invokeMethod<bool>('requestDefaultSmsApp');
    return result ?? false;
  }

  Future<List<SmsConversation>> getConversations() async {
    final result = await _channel.invokeMethod<List<Object?>>('getConversations');
    return (result ?? const [])
        .map((e) => SmsConversation.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  Future<List<SmsMessage>> getMessages(String threadId) async {
    final result = await _channel.invokeMethod<List<Object?>>('getMessages', {'threadId': threadId});
    return (result ?? const []).map((e) => SmsMessage.fromMap(e as Map<dynamic, dynamic>)).toList();
  }

  Future<SentSms> sendSms({required String address, required String body}) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('sendSms', {'address': address, 'body': body});
    final map = asMap(result);
    return SentSms(id: asString(map['id']), threadId: asString(map['threadId']));
  }

  /// Resolves (creating if necessary) the thread id for [address] — used to
  /// open a thread screen for a brand-new conversation before any message
  /// has been sent yet (e.g. composing from a contact or an `sms:` link).
  Future<String> getOrCreateThreadId(String address) async {
    final result = await _channel.invokeMethod<String>('getOrCreateThreadId', {'address': address});
    return result ?? '';
  }

  Future<void> markThreadRead(String threadId) {
    return _channel.invokeMethod('markThreadRead', {'threadId': threadId});
  }

  /// New messages that arrive while the app is in the foreground (native
  /// side only pushes here while something is actually listening).
  Stream<SmsMessage> incomingMessages() {
    return _incoming.receiveBroadcastStream().map((e) => SmsMessage.fromMap(e as Map<dynamic, dynamic>));
  }
}
