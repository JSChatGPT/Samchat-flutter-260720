package com.samafricaonline.samchat.telecom

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Plays the actual ring — a self-managed ConnectionService gets you Telecom
 * integration (audio focus, Bluetooth/wired-headset answer button, proper
 * "there's a call" system state), but is NOT given a ringtone for free the
 * way a carrier-style (managed) ConnectionService is; the app has to ring
 * itself. Loops the device's default ringtone (not notification sound) plus
 * a repeating vibration pattern, exactly like a real incoming call, until
 * [stop] is called (answered/declined/timed out/aborted).
 */
object IncomingCallRinger {
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    fun start(context: Context) {
        stop() // never double-start if a previous ring wasn't cleanly stopped

        try {
            val ringtoneUri = RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
            if (ringtoneUri != null) {
                mediaPlayer = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    setDataSource(context, ringtoneUri)
                    isLooping = true
                    prepare()
                    start()
                }
            }
        } catch (e: Exception) {
            // Best-effort — a failed ringtone shouldn't block showing/answering the call.
        }

        try {
            val pattern = longArrayOf(0, 800, 800) // wait, vibrate, pause — repeats
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 1))
        } catch (e: Exception) {
            // Best-effort — see above.
        }
    }

    fun stop() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
        } catch (e: Exception) {
            // Already stopped/released — nothing to do.
        }
        mediaPlayer = null

        try {
            vibrator?.cancel()
        } catch (e: Exception) {
            // Ignored.
        }
        vibrator = null
    }
}
