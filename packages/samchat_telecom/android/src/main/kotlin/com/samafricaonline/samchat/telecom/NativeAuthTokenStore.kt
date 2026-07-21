package com.samafricaonline.samchat.telecom

import android.content.Context

/**
 * A plain (non-encrypted) copy of the Sanctum bearer token, written from
 * Dart (see SamchatTelecomPlugin's syncAuthToken) every time it changes, so
 * SamChatConnection can decline a call over plain HTTP entirely natively —
 * answering a call needs the Flutter/WebRTC engine running anyway (that's
 * where the actual media lives), but declining is just one POST, and
 * shouldn't have to wait for a cold Flutter engine to boot first just to
 * make it.
 *
 * Deliberately a separate store from flutter_secure_storage's own
 * EncryptedSharedPreferences file rather than reading that one directly:
 * its file name/key alias are an internal implementation detail of that
 * plugin, not a stable contract to depend on from native code. A stolen
 * device already has the app installed and (while unlocked) usable, so a
 * plain copy of a short-lived bearer token adds negligible extra exposure
 * next to a full un-authed decline-only endpoint call.
 */
object NativeAuthTokenStore {
    private const val PREFS_NAME = "samchat_native_call_prefs"
    private const val KEY_TOKEN = "auth_token"
    private const val KEY_API_BASE_URL = "api_base_url"

    fun write(context: Context, token: String?) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (token.isNullOrEmpty()) {
            prefs.edit().remove(KEY_TOKEN).apply()
        } else {
            prefs.edit().putString(KEY_TOKEN, token).apply()
        }
    }

    fun read(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).getString(KEY_TOKEN, null)
    }

    /** AppConfig.apiBaseUrl — a Dart-side compile-time constant, so it's synced
     * once at startup (see SamchatTelecomPlugin) rather than hardcoded here. */
    fun writeApiBaseUrl(context: Context, url: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().putString(KEY_API_BASE_URL, url).apply()
    }

    fun readApiBaseUrl(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).getString(KEY_API_BASE_URL, null)
    }
}
