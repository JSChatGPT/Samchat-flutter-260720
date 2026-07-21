import 'package:flutter/services.dart';

/// Dart-side API for the native Android Telecom (self-managed
/// ConnectionService) bridge — see the native SamchatTelecomPlugin for the
/// other side of each of these calls. All static/no-op-safe on non-Android
/// platforms (every method just does nothing there).
class SamchatTelecom {
  SamchatTelecom._();

  static const _channel = MethodChannel('samchat/telecom');

  /// Call once at app startup (idempotent).
  static Future<void> registerPhoneAccount() async {
    try {
      await _channel.invokeMethod('registerPhoneAccount');
    } catch (_) {
      // Best-effort — e.g. non-Android platform, or plugin not yet ready.
    }
  }

  /// Hands an incoming call to Telecom so it rings/is answerable like a real
  /// phone call. Returns whether Telecom actually took it (false on
  /// pre-Android-8 devices, or any other platform) — the caller should fall
  /// back to a plain notification when this is false.
  static Future<bool> reportIncomingCall({
    required String callId,
    String? callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? chatId,
  }) async {
    try {
      final handled = await _channel.invokeMethod<bool>('reportIncomingCall', {
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'callerPhoto': callerPhoto,
        'isVideo': isVideo,
        'chatId': chatId,
      });
      return handled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Keeps the native side's copy of the bearer token current — needed so a
  /// Decline tapped from the notification (no Flutter engine involved) can
  /// still make the one HTTP call it needs, entirely natively. Call
  /// whenever the token changes (login, refresh, logout-clear with null).
  static Future<void> syncAuthToken(String? token) async {
    try {
      await _channel.invokeMethod('syncAuthToken', {'token': token});
    } catch (_) {}
  }

  /// Call once at startup with AppConfig.apiBaseUrl — a Dart compile-time
  /// constant the native side has no other way to know.
  static Future<void> syncApiBaseUrl(String url) async {
    try {
      await _channel.invokeMethod('syncApiBaseUrl', {'url': url});
    } catch (_) {}
  }

  /// Tells the native Connection for [callId] (if any) that the app itself
  /// ended the call, so Telecom's state stays in sync with what the
  /// Flutter/WebRTC side actually did.
  static Future<void> endCall(String callId) async {
    try {
      await _channel.invokeMethod('endCall', {'callId': callId});
    } catch (_) {}
  }
}
