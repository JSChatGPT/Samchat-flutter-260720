package com.samafricaonline.samchat.sms

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.app.RemoteInput

/**
 * Handles the "Reply" quick-action on an incoming-SMS notification — entirely
 * native, no Flutter engine involved, since sending a plain SMS reply is just
 * an SmsManager call (see SmsSender). Mirrors SmsDeliverReceiver.onMessage's
 * live-update payload shape so an open thread screen reflects the reply
 * immediately even though it never went through the Dart-side send path.
 */
class SmsReplyReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_ADDRESS = "address"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val REPLY_KEY = "sms_reply_text"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val address = intent.getStringExtra(EXTRA_ADDRESS) ?: return
        val body = RemoteInput.getResultsFromIntent(intent)
            ?.getCharSequence(REPLY_KEY)?.toString()?.trim()
        if (body.isNullOrEmpty()) return

        SmsSender.send(context, address, body)

        val payload = mapOf(
            "id" to "",
            "threadId" to SmsSender.threadIdFor(context, address).toString(),
            "address" to address,
            "body" to body,
            "date" to System.currentTimeMillis(),
            "outgoing" to true,
        )
        Handler(Looper.getMainLooper()).post { SmsDeliverReceiver.onMessage?.invoke(payload) }

        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        if (notificationId != -1) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(notificationId)
        }
    }
}
