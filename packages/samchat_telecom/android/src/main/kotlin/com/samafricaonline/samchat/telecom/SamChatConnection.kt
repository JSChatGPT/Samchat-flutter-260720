package com.samafricaonline.samchat.telecom

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.telecom.Connection
import android.telecom.DisconnectCause
import android.telecom.TelecomManager
import androidx.core.app.NotificationCompat
import java.net.HttpURLConnection
import java.net.URL

/**
 * One ringing/active call, represented to Android's Telecom framework. This
 * is what actually gets us "rings and is answerable like a real phone call":
 * Telecom handles audio focus, Bluetooth/wired-headset answer-button
 * routing, and correctly interrupting/coexisting with other calls — none of
 * which a plain notification (however fancy) gives you, no matter how it's
 * styled. The ring itself and the visible incoming-call UI are still this
 * app's own responsibility (self-managed, unlike a carrier-style
 * ConnectionService) — see [IncomingCallRinger] and [showFullScreenNotification].
 *
 * Lives in this plugin module (not the app module) purely so it's
 * reachable from the headless FlutterEngine used for background FCM
 * handling — see this package's pubspec.yaml. Because of that, it can't
 * hold a compile-time reference to the host app's MainActivity class (that
 * would be a circular module dependency), hence launching it by package-
 * qualified class name via Intent.setClassName instead of a direct import.
 */
class SamChatConnection(
    private val appContext: Context,
    val callId: String,
    private val callerName: String,
    private val callerPhoto: String?,
    private val callerId: String?,
    private val isVideo: Boolean,
    private val chatId: String?,
) : Connection() {

    init {
        setCallerDisplayName(callerName, TelecomManager.PRESENTATION_ALLOWED)
        setAddress(Uri.fromParts("tel", callId, null), TelecomManager.PRESENTATION_ALLOWED)
        audioModeIsVoip = true
        connectionProperties = PROPERTY_SELF_MANAGED
        connectionCapabilities = CAPABILITY_MUTE
        setRinging()
    }

    override fun onShowIncomingCallUi() {
        IncomingCallRinger.start(appContext)
        showFullScreenNotification()
    }

    override fun onAnswer() = handleAnswer()

    override fun onReject() = handleReject()

    override fun onReject(rejectMessage: String?) = handleReject()

    override fun onAbort() = handleReject()

    override fun onDisconnect() {
        IncomingCallRinger.stop()
        dismissNotification()
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
        SamChatConnectionService.forget(callId)
    }

    /** Our own UI triggering answer/decline (notification action tap) —
     * as opposed to [onAnswer]/[onReject], which fire when *Telecom*
     * decides to (a Bluetooth device, Android Auto, etc.). Both converge on
     * the same handling either way. */
    fun answerFromUi() = handleAnswer()

    fun rejectFromUi() = handleReject()

    /** Called when the *app itself* (in-app "End" button, via
     * SamchatTelecomPlugin) is tearing down a call that was already
     * answered — keeps Telecom's state in sync with what the Flutter/WebRTC
     * side actually did. */
    fun endFromApp() {
        IncomingCallRinger.stop()
        dismissNotification()
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
        SamChatConnectionService.forget(callId)
    }

    private fun handleAnswer() {
        IncomingCallRinger.stop()
        dismissNotification()
        setActive()
        launchAnswerUi()
        // Deliberately not destroy()/forget() here — the connection stays
        // registered (now ACTIVE) for the rest of the call, so ending it
        // later from the in-app UI has a live Connection to disconnect.
    }

    private fun handleReject() {
        IncomingCallRinger.stop()
        dismissNotification()
        setDisconnected(DisconnectCause(DisconnectCause.REJECTED))
        destroy()
        SamChatConnectionService.forget(callId)
        declineOverHttp()
    }

    private fun answerCallIntent(): Intent {
        return Intent().apply {
            setClassName(appContext.packageName, "com.samafricaonline.samchat.MainActivity")
            action = ACTION_ANSWER_CALL_UI
            putExtra("callId", callId)
            putExtra("callerId", callerId)
            putExtra("callerName", callerName)
            putExtra("callerPhoto", callerPhoto)
            putExtra("isVideo", isVideo)
            putExtra("chatId", chatId)
        }
    }

    private fun launchAnswerUi() {
        val intent = answerCallIntent().apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        appContext.startActivity(intent)
    }

    /** Best-effort — declining doesn't need the Flutter engine at all (unlike
     * answering, which needs it to actually join the WebRTC media), so this
     * is a plain native HTTP call using the token SamchatTelecomPlugin keeps
     * synced. If this fails for any reason, the caller's own 45s
     * ring-timeout ends the call from their side anyway. */
    private fun declineOverHttp() {
        val token = NativeAuthTokenStore.read(appContext) ?: return
        val baseUrl = NativeAuthTokenStore.readApiBaseUrl(appContext) ?: return
        val id = callId
        Thread {
            try {
                val url = URL("$baseUrl/calls/$id/decline")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Authorization", "Bearer $token")
                conn.setRequestProperty("Accept", "application/json")
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                conn.responseCode // forces the request to actually fire
                conn.disconnect()
            } catch (e: Exception) {
                // Best-effort — see kdoc above.
            }
        }.start()
    }

    private fun showFullScreenNotification() {
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm.getNotificationChannel(CHANNEL_ID) == null) {
            val channel = android.app.NotificationChannel(CHANNEL_ID, "Incoming calls", NotificationManager.IMPORTANCE_MAX).apply {
                // IncomingCallRinger already plays a proper looping ringtone —
                // a channel sound/vibration here would compete with it.
                setSound(null, null)
                enableVibration(false)
            }
            nm.createNotificationChannel(channel)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            appContext,
            callId.hashCode(),
            answerCallIntent().apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val answerPendingIntent = PendingIntent.getBroadcast(
            appContext,
            callId.hashCode() + 1,
            Intent(appContext, CallActionReceiver::class.java).apply {
                action = CallActionReceiver.ACTION_ANSWER
                putExtra("callId", callId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val declinePendingIntent = PendingIntent.getBroadcast(
            appContext,
            callId.hashCode() + 2,
            Intent(appContext, CallActionReceiver::class.java).apply {
                action = CallActionReceiver.ACTION_DECLINE
                putExtra("callId", callId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(appContext.applicationInfo.icon)
            .setContentTitle(if (isVideo) "Incoming video call" else "Incoming call")
            .setContentText(callerName)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(0, "Decline", declinePendingIntent)
            .addAction(0, "Answer", answerPendingIntent)
            .build()
        nm.notify(NOTIFICATION_ID, notification)
    }

    private fun dismissNotification() {
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(NOTIFICATION_ID)
    }

    companion object {
        const val ACTION_ANSWER_CALL_UI = "com.samafricaonline.samchat.ANSWER_CALL_UI"
        private const val CHANNEL_ID = "samchat_calls_telecom"
        private const val NOTIFICATION_ID = 7801
    }
}
