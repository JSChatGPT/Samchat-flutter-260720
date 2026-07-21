package com.samafricaonline.samchat.sms

import android.content.ContentValues
import android.content.Context
import android.provider.Telephony
import android.telephony.SmsManager

/**
 * Sends a plain SMS and — since only the default SMS app is allowed to write
 * into the shared provider — records it into `content://sms/sent` ourselves
 * so it shows up in the system's own SMS history (and after re-reading it
 * back, in this app's own thread view too).
 */
object SmsSender {
    /** AOSP's own trigger-based thread_id assignment isn't guaranteed across OEM
     * provider forks — resolving it explicitly (same call Android's own Messages
     * app makes) keeps conversation grouping reliable. */
    fun threadIdFor(context: Context, address: String): Long =
        Telephony.Threads.getOrCreateThreadId(context, setOf(address))

    fun send(context: Context, address: String, body: String): Long {
        val manager = SmsManager.getDefault()
        val parts = manager.divideMessage(body)
        if (parts.size > 1) {
            manager.sendMultipartTextMessage(address, null, parts, null, null)
        } else {
            manager.sendTextMessage(address, null, body, null, null)
        }

        val values = ContentValues().apply {
            put(Telephony.Sms.ADDRESS, address)
            put(Telephony.Sms.BODY, body)
            put(Telephony.Sms.DATE, System.currentTimeMillis())
            put(Telephony.Sms.READ, 1)
            put(Telephony.Sms.SEEN, 1)
            put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
            put(Telephony.Sms.THREAD_ID, threadIdFor(context, address))
        }
        val uri = context.contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
        return uri?.lastPathSegment?.toLongOrNull() ?: -1L
    }
}
