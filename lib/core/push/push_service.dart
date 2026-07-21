import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../api/endpoints.dart';
import 'fcm_background_handler.dart';
import 'local_notifications_service.dart';
import 'notification_actions.dart';

enum PushNavigationType { chat, incomingCall, email }

class PushNavigationTarget {
  const PushNavigationTarget(this.type, {this.chatId, this.callId, this.emailAccountId});

  final PushNavigationType type;
  final String? chatId;
  final String? callId;
  final String? emailAccountId;
}

/// FCM wiring per API_DOCUMENTATION.md §10. Entirely best-effort: until a
/// real Firebase project is configured (google-services.json /
/// GoogleService-Info.plist), `Firebase.initializeApp()` throws and this
/// silently no-ops — same "no crash, just no push" behavior the backend
/// itself documents for a missing `FIREBASE_CREDENTIALS`.
class PushService {
  PushService({required Dio dio, required LocalNotificationsService notifications})
      : _dio = dio,
        _notifications = notifications;

  final Dio _dio;
  final LocalNotificationsService _notifications;
  bool _ready = false;
  String? _lastToken;

  /// Set by chat_detail_screen while mounted so a foreground push for the
  /// chat currently on screen can be suppressed (still delivered for
  /// badge/data-sync purposes, just not shown as a visible banner) — the
  /// server pushes to every other participant unconditionally per the doc.
  String? currentlyOpenChatId;

  final _navigationController = StreamController<PushNavigationTarget>.broadcast();
  Stream<PushNavigationTarget> get onNavigate => _navigationController.stream;

  Future<void> init() async {
    if (_ready) return; // already initialized this app session (e.g. re-login after logout)
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') {
        return;
      }
    } catch (_) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
    await _notifications.init(onTap: _onLocalNotificationTap);

    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
    } catch (_) {
      return;
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _onMessageOpenedApp(initialMessage);

    _ready = true;
  }

  Future<void> _registerToken(String token) async {
    _lastToken = token;
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await _dio.post(Endpoints.deviceToken, data: {'token': token, 'platform': platform});
    } catch (_) {
      // Non-fatal — will retry on next app start / token refresh.
    }
  }

  Future<void> unregister() async {
    if (_lastToken == null) return;
    try {
      await _dio.delete(Endpoints.deviceToken, data: {'token': _lastToken});
    } catch (_) {}
    _lastToken = null;
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];
    if (type == 'incoming_call') {
      // The realtime IncomingCall socket event already drives the in-app
      // full-screen route while foregrounded — the push is redundant here.
      return;
    }
    if (type == 'message') {
      final chatId = data['chat_id']?.toString();
      if (chatId != null && chatId == currentlyOpenChatId) return; // suppress banner for open chat
      // The push is data-only now (see PushNotificationService::sendToUser)
      // — title/body ride along in `data` rather than `message.notification`,
      // which the server deliberately never sets.
      final body = await decryptPushMessageBody(data, fallback: data['body']?.toString() ?? '');
      _notifications.showMessageNotification(
        id: data['message_id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        title: data['title']?.toString() ?? 'New message',
        body: body,
        payload: 'message:$chatId',
      );
    }
    if (type == 'new_email') {
      // The `NewEmailReceived` socket event (see email_notifier.dart's
      // emailRealtimeListenerProvider) already refreshes the badge counts
      // live while foregrounded — this just surfaces a visible banner,
      // same as the 'message' case above.
      final accountId = data['email_account_id']?.toString();
      final emailId = data['email_id']?.toString();
      _notifications.showEmailNotification(
        id: accountId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        title: data['title']?.toString() ?? 'New email',
        body: data['body']?.toString() ?? '',
        payload: emailId != null ? 'new_email:$accountId:$emailId' : 'new_email:$accountId',
        replyable: emailId != null,
      );
    }
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      _navigationController.add(PushNavigationTarget(PushNavigationType.incomingCall, callId: data['call_id']));
    } else if (data['type'] == 'message') {
      _navigationController.add(PushNavigationTarget(PushNavigationType.chat, chatId: data['chat_id']));
    } else if (data['type'] == 'new_email') {
      _navigationController.add(PushNavigationTarget(PushNavigationType.email, emailAccountId: data['email_account_id']));
    }
  }

  void _onLocalNotificationTap(String? payload) {
    if (payload == null) return;
    final parts = payload.split(':');
    if (parts.length < 2) return;
    if (parts[0] == 'incoming_call') {
      _navigationController.add(PushNavigationTarget(PushNavigationType.incomingCall, callId: parts[1]));
    } else if (parts[0] == 'message') {
      _navigationController.add(PushNavigationTarget(PushNavigationType.chat, chatId: parts[1]));
    } else if (parts[0] == 'new_email') {
      _navigationController.add(PushNavigationTarget(PushNavigationType.email, emailAccountId: parts[1]));
    }
  }

  bool get isReady => _ready;

  void dispose() {
    _navigationController.close();
  }
}
