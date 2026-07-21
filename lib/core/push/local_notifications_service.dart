import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_actions.dart';

/// Wraps flutter_local_notifications: the visible banner for foreground
/// messages, and the full-screen-intent incoming-call notification used when
/// the socket is dead (app killed/backgrounded) — see push_service.dart.
class LocalNotificationsService {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _messagesChannel = AndroidNotificationChannel(
    'samchat_messages',
    'Messages',
    description: 'New chat messages',
    importance: Importance.high,
  );

  /// `_v2`: audioAttributesUsage is a channel-level Android setting, locked
  /// in the first time a channel id is created on-device — bumping the id
  /// is the only way for an already-installed app to pick up the switch to
  /// a ringtone-style (looping) sound instead of a one-shot notification
  /// blip. See showIncomingCallNotification below for why this matters.
  static const _callsChannel = AndroidNotificationChannel(
    'samchat_calls_v2',
    'Calls',
    description: 'Incoming calls',
    importance: Importance.max,
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
  );

  static const _emailsChannel = AndroidNotificationChannel(
    'samchat_emails',
    'Email',
    description: 'New email arrivals',
    importance: Importance.high,
  );

  static const _replyAction = AndroidNotificationAction(
    'reply',
    'Reply',
    showsUserInterface: false,
    cancelNotification: true,
    inputs: [AndroidNotificationActionInput(label: 'Message')],
  );

  Future<void> init({required void Function(String? payload) onTap}) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        // Action-button taps (Reply / Decline) are handled entirely
        // standalone — see notification_actions.dart — rather than routed
        // through the app's navigation callback, since they shouldn't open
        // any screen at all.
        if (response.actionId == 'reply' || response.actionId == 'decline') {
          handleNotificationAction(response);
          return;
        }
        onTap(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: handleNotificationAction,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_messagesChannel);
    await androidPlugin?.createNotificationChannel(_callsChannel);
    await androidPlugin?.createNotificationChannel(_emailsChannel);
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> showMessageNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) {
    return _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _messagesChannel.id,
          _messagesChannel.name,
          channelDescription: _messagesChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          actions: const [_replyAction],
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// [replyable] should only be true when [payload] unambiguously identifies
  /// a single email (i.e. carries an email id, not just an account id) — a
  /// batched "3 new emails" notification can't sensibly offer a one-tap
  /// reply aimed at just one of them.
  Future<void> showEmailNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
    bool replyable = false,
  }) {
    return _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _emailsChannel.id,
          _emailsChannel.name,
          channelDescription: _emailsChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          actions: replyable ? const [_replyAction] : null,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Full-screen incoming-call notification — shows over the lock screen on
  /// Android (requires `USE_FULL_SCREEN_INTENT` + the activity flags already
  /// set in AndroidManifest.xml) and rings continuously rather than playing
  /// a single blip: `AudioAttributesUsage.notificationRingtone` on the
  /// channel (above) tells Android to treat this sound the way it treats an
  /// actual incoming-call ringtone — looped until answered/declined/timed
  /// out — instead of the one-shot behavior a plain notification sound gets.
  /// `ongoing`/`autoCancel: false` stop a stray swipe from silently
  /// dismissing it, and `timeoutAfter` auto-cancels it as a missed call
  /// after 45s if nobody responds.
  Future<void> showIncomingCallNotification({
    required int id,
    required String callerName,
    required String payload,
  }) {
    return _plugin.show(
      id,
      'Incoming call',
      callerName,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _callsChannel.id,
          _callsChannel.name,
          channelDescription: _callsChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          ongoing: true,
          autoCancel: false,
          timeoutAfter: 45000,
          actions: const [
            AndroidNotificationAction('decline', 'Decline', cancelNotification: true),
            AndroidNotificationAction('answer', 'Answer', showsUserInterface: true, cancelNotification: true),
          ],
        ),
        iOS: const DarwinNotificationDetails(interruptionLevel: InterruptionLevel.timeSensitive),
      ),
      payload: payload,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
}
