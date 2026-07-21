package com.samafricaonline.samchat.sms

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * The other mandatory component for default-SMS-app eligibility: handles
 * "quick reply" (e.g. replying to a missed-call notification via SMS)
 * without opening the app UI.
 */
class HeadlessSmsSendService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "android.intent.action.RESPOND_VIA_MESSAGE") {
            val address = intent.data?.schemeSpecificPart
            val body = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!address.isNullOrEmpty() && !body.isNullOrEmpty()) {
                SmsSender.send(applicationContext, address, body)
            }
        }
        stopSelf(startId)
        return START_NOT_STICKY
    }
}
