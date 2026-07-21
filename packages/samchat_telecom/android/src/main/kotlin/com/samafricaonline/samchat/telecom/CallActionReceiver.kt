package com.samafricaonline.samchat.telecom

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Answer/Decline tap targets on the incoming-call notification (see
 * SamChatConnection.showFullScreenNotification) — looks up the live
 * Connection for this call_id and forwards to it. Entirely native; no
 * Flutter engine involved for Decline, and Answer's own app-launch happens
 * inside SamChatConnection itself once it's told to answer.
 */
class CallActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_ANSWER = "com.samafricaonline.samchat.telecom.ACTION_ANSWER"
        const val ACTION_DECLINE = "com.samafricaonline.samchat.telecom.ACTION_DECLINE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val callId = intent.getStringExtra("callId") ?: return
        val connection = SamChatConnectionService.findConnection(callId) ?: return
        when (intent.action) {
            ACTION_ANSWER -> connection.answerFromUi()
            ACTION_DECLINE -> connection.rejectFromUi()
        }
    }
}
