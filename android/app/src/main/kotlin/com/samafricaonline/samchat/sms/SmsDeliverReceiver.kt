package com.samafricaonline.samchat.sms

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import com.samafricaonline.samchat.MainActivity

/**
 * Handles `SMS_DELIVER` — only ever delivered to the current default SMS app.
 * As the default app we are responsible for persisting the message into the
 * shared `content://sms` provider ourselves (the OS does not do this for us);
 * skipping that would silently lose messages from the system's own SMS
 * database and any other app that reads it.
 */
class SmsDeliverReceiver : BroadcastReceiver() {

    companion object {
        // Set by SmsPlugin while its EventChannel has an active Dart-side
        // listener (app in foreground) for a live, no-poll UI update.
        var onMessage: ((Map<String, Any?>) -> Unit)? = null
        private const val CHANNEL_ID = "samchat_messages"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_DELIVER_ACTION) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val address = messages[0].originatingAddress ?: return
        val body = messages.joinToString("") { it.messageBody ?: "" }
        val timestamp = messages[0].timestampMillis

        val threadId = SmsSender.threadIdFor(context, address)
        val values = ContentValues().apply {
            put(Telephony.Sms.ADDRESS, address)
            put(Telephony.Sms.BODY, body)
            put(Telephony.Sms.DATE, timestamp)
            put(Telephony.Sms.READ, 0)
            put(Telephony.Sms.SEEN, 0)
            put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
            put(Telephony.Sms.THREAD_ID, threadId)
        }
        val uri = context.contentResolver.insert(Telephony.Sms.Inbox.CONTENT_URI, values)

        val payload = mapOf(
            "id" to (uri?.lastPathSegment ?: ""),
            "threadId" to threadId.toString(),
            "address" to address,
            "body" to body,
            "date" to timestamp,
            "outgoing" to false,
        )
        Handler(Looper.getMainLooper()).post { onMessage?.invoke(payload) }

        showNotification(context, address, body)
    }

    private fun showNotification(context: Context, address: String, body: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Messages", NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = "New chat messages" },
            )
        }

        val notificationId = address.hashCode()

        val openIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.samafricaonline.samchat.OPEN_SMS_THREAD"
            putExtra("address", address)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // Direct-reply action (WhatsApp-style) — handled entirely by
        // SmsReplyReceiver without needing the Flutter engine running.
        // RemoteInput-carrying PendingIntents must be mutable: the system
        // fills in the typed text before delivering the broadcast.
        val replyIntent = Intent(context, SmsReplyReceiver::class.java).apply {
            putExtra(SmsReplyReceiver.EXTRA_ADDRESS, address)
            putExtra(SmsReplyReceiver.EXTRA_NOTIFICATION_ID, notificationId)
        }
        val replyPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        val replyAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_send,
            "Reply",
            replyPendingIntent,
        ).addRemoteInput(
            RemoteInput.Builder(SmsReplyReceiver.REPLY_KEY).setLabel("Message").build(),
        ).build()

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(address)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .addAction(replyAction)
            .build()
        nm.notify(notificationId, notification)
    }
}
