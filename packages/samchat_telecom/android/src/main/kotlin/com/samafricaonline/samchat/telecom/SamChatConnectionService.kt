package com.samafricaonline.samchat.telecom

import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager

/**
 * Registers SamChat as a self-managed calling app with Android's Telecom
 * framework — the same mechanism WhatsApp/Messenger use so an incoming call
 * rings and is answerable straight from the lock screen (and via a
 * Bluetooth/wired-headset answer button, with proper audio focus/routing),
 * instead of behaving like an ordinary notification. Only incoming calls are
 * registered here — outgoing calls keep using the existing in-app "Calling…"
 * screen, which only ever needs to work while the app is already open.
 *
 * Self-managed ConnectionServices require API 26 — [registerPhoneAccount]/
 * [reportIncomingCall] are no-ops below that (the app's minSdk is 24), so
 * those very old devices simply keep the older notification-only ring
 * behavior instead of crashing.
 */
class SamChatConnectionService : ConnectionService() {

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ): Connection {
        val extras = request?.extras ?: Bundle()
        val callId = extras.getString(EXTRA_CALL_ID) ?: ""
        val callerName = extras.getString(EXTRA_CALLER_NAME) ?: "Someone"
        val callerPhoto = extras.getString(EXTRA_CALLER_PHOTO)
        val callerId = extras.getString(EXTRA_CALLER_ID)
        val isVideo = extras.getBoolean(EXTRA_IS_VIDEO, false)
        val chatId = extras.getString(EXTRA_CHAT_ID)

        val connection = SamChatConnection(applicationContext, callId, callerName, callerPhoto, callerId, isVideo, chatId)
        activeConnections[callId] = connection
        return connection
    }

    override fun onCreateIncomingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ) {
        super.onCreateIncomingConnectionFailed(connectionManagerPhoneAccount, request)
        val callId = request?.extras?.getString(EXTRA_CALL_ID)
        if (callId != null) reportedCallIds.remove(callId)
    }

    companion object {
        private const val EXTRA_CALL_ID = "callId"
        private const val EXTRA_CALLER_NAME = "callerName"
        private const val EXTRA_CALLER_PHOTO = "callerPhoto"
        private const val EXTRA_CALLER_ID = "callerId"
        private const val EXTRA_IS_VIDEO = "isVideo"
        private const val EXTRA_CHAT_ID = "chatId"

        private val activeConnections = mutableMapOf<String, SamChatConnection>()

        // A call_id this device has already handed to Telecom — guards
        // against reporting the same incoming call twice (e.g. the FCM push
        // background handler firing more than once for the same message).
        private val reportedCallIds = mutableSetOf<String>()

        fun findConnection(callId: String): SamChatConnection? = activeConnections[callId]

        fun forget(callId: String) {
            activeConnections.remove(callId)
            reportedCallIds.remove(callId)
        }

        private fun phoneAccountHandle(context: Context): PhoneAccountHandle {
            return PhoneAccountHandle(
                ComponentName(context, SamChatConnectionService::class.java),
                "SamChatCalling",
            )
        }

        /** Call once at app startup (idempotent — re-registering is harmless). */
        fun registerPhoneAccount(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            val handle = phoneAccountHandle(context)
            val account = PhoneAccount.builder(handle, "SamChat")
                .setCapabilities(PhoneAccount.CAPABILITY_SELF_MANAGED)
                .build()
            telecomManager.registerPhoneAccount(account)
        }

        /** Hands an incoming call to Telecom — triggers [onCreateIncomingConnection]
         * above, which is what actually makes it ring like a real call.
         * Returns whether it was actually handed off (false below API 26). */
        fun reportIncomingCall(
            context: Context,
            callId: String,
            callerId: String?,
            callerName: String,
            callerPhoto: String?,
            isVideo: Boolean,
            chatId: String?,
        ): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
            if (callId.isEmpty() || reportedCallIds.contains(callId)) return false
            reportedCallIds.add(callId)

            val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            val handle = phoneAccountHandle(context)
            val extras = Bundle().apply {
                putString(EXTRA_CALL_ID, callId)
                putString(EXTRA_CALLER_ID, callerId)
                putString(EXTRA_CALLER_NAME, callerName)
                putString(EXTRA_CALLER_PHOTO, callerPhoto)
                putBoolean(EXTRA_IS_VIDEO, isVideo)
                putString(EXTRA_CHAT_ID, chatId)
            }
            return try {
                telecomManager.addNewIncomingCall(handle, extras)
                true
            } catch (e: Exception) {
                // Account not registered yet, or some other Telecom-side
                // rejection — let the caller fall back to a plain
                // notification instead.
                reportedCallIds.remove(callId)
                false
            }
        }
    }
}
