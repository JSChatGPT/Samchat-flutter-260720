import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:samchat_telecom/samchat_telecom.dart';

import 'local_notifications_service.dart';
import 'notification_actions.dart';

/// Runs in a separate background isolate with no access to the app's
/// ProviderContainer, Riverpod state, or the realtime Pusher connection —
/// it can only do isolated work like showing a local notification. Routing
/// into the app happens later, from the notification-tap handler once the
/// main isolate is running (see push_service.dart).
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  final type = data['type'];

  if (type == 'incoming_call') {
    // Hands the call to Android's Telecom framework (self-managed
    // ConnectionService — see the samchat_telecom plugin) so it rings and
    // is answerable straight from the lock screen like a real phone call,
    // instead of behaving like an ordinary notification. Falls back to the
    // old plain full-screen notification only if Telecom genuinely
    // couldn't take it (pre-Android-8 devices, or some other platform).
    final handledByTelecom = await SamchatTelecom.reportIncomingCall(
      callId: data['call_id']?.toString() ?? '',
      callerId: data['caller_id']?.toString(),
      callerName: data['caller_name']?.toString() ?? 'Someone',
      callerPhoto: data['caller_photo']?.toString(),
      isVideo: data['call_type']?.toString() == 'video',
      chatId: data['chat_id']?.toString(),
    );
    if (!handledByTelecom) {
      final notifications = LocalNotificationsService();
      await notifications.init(onTap: (_) {});
      await notifications.showIncomingCallNotification(
        id: data['call_id']?.hashCode ?? 0,
        callerName: data['caller_name']?.toString() ?? 'Someone',
        payload: 'incoming_call:${data['call_id']}',
      );
    }
    return;
  }

  final notifications = LocalNotificationsService();
  await notifications.init(onTap: (_) {});

  if (type == 'message') {
    // Data-only push (see PushNotificationService::sendToUser) — title/body
    // ride along in `data`, not `message.notification` (never set).
    final body = await decryptPushMessageBody(data, fallback: data['body']?.toString() ?? '');
    await notifications.showMessageNotification(
      id: data['message_id']?.hashCode ?? 0,
      title: data['title']?.toString() ?? 'New message',
      body: body,
      payload: 'message:${data['chat_id']}',
    );
  } else if (type == 'reaction') {
    await notifications.showMessageNotification(
      id: data['message_id']?.hashCode ?? 0,
      title: data['title']?.toString() ?? 'New reaction',
      body: data['body']?.toString() ?? '',
      payload: 'message:${data['chat_id']}',
    );
  } else if (type == 'new_email') {
    final accountId = data['email_account_id']?.toString();
    final emailId = data['email_id']?.toString();
    await notifications.showEmailNotification(
      id: accountId?.hashCode ?? 0,
      title: data['title']?.toString() ?? 'New email',
      body: data['body']?.toString() ?? '',
      payload: emailId != null ? 'new_email:$accountId:$emailId' : 'new_email:$accountId',
      replyable: emailId != null,
    );
  }
}
