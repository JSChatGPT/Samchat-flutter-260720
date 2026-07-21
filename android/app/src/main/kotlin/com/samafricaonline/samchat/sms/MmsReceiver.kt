package com.samafricaonline.samchat.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Android requires a `WAP_PUSH_DELIVER` receiver for an app to be offered as
 * a default-SMS-app candidate at all, even if it doesn't do anything with
 * MMS — this app is plain-SMS-only for now, so this intentionally no-ops.
 */
class MmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Intentionally empty — see class doc.
    }
}
