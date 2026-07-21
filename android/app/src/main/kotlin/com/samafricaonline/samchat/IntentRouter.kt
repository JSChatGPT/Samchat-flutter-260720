package com.samafricaonline.samchat

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import java.io.File
import java.io.FileOutputStream

/**
 * Turns an Android Intent (SMS notification tap, sms:/smsto: compose, or a
 * share-sheet SEND/SEND_MULTIPLE from another app) into a plain map Dart can
 * route on, and materializes any shared content:// stream into a real file
 * path since Dart/dart:io can't read content:// URIs directly.
 */
object IntentRouter {
    fun parse(context: Context, intent: Intent?): Map<String, Any?>? {
        intent ?: return null
        return when (intent.action) {
            "com.samafricaonline.samchat.OPEN_SMS_THREAD" -> {
                val address = intent.getStringExtra("address")
                if (address.isNullOrEmpty()) null else mapOf("type" to "sms_thread", "address" to address)
            }
            "com.samafricaonline.samchat.OPEN_USER_CHAT" -> {
                val userId = intent.getStringExtra("userId")
                if (userId.isNullOrEmpty()) null else mapOf("type" to "open_user_chat", "userId" to userId)
            }
            // Fired by SamChatConnection (samchat_telecom plugin) when the
            // incoming-call notification's full-screen intent/Answer action
            // launches this Activity — see that class for why it can't
            // reference MainActivity directly (action string match instead).
            "com.samafricaonline.samchat.ANSWER_CALL_UI" -> {
                val callId = intent.getStringExtra("callId")
                if (callId.isNullOrEmpty()) null else mapOf(
                    "type" to "answer_call",
                    "callId" to callId,
                    "callerId" to intent.getStringExtra("callerId"),
                    "callerName" to intent.getStringExtra("callerName"),
                    "callerPhoto" to intent.getStringExtra("callerPhoto"),
                    "isVideo" to intent.getBooleanExtra("isVideo", false),
                    "chatId" to intent.getStringExtra("chatId"),
                )
            }
            Intent.ACTION_SENDTO -> {
                val address = intent.data?.schemeSpecificPart
                if (address.isNullOrEmpty()) null else mapOf("type" to "sms_compose", "address" to address)
            }
            Intent.ACTION_SEND -> parseSend(context, intent)
            Intent.ACTION_SEND_MULTIPLE -> parseSendMultiple(context, intent)
            else -> null
        }
    }

    private fun parseSend(context: Context, intent: Intent): Map<String, Any?>? {
        val mimeType = intent.type ?: return null
        if (mimeType.startsWith("text/")) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
            return mapOf("type" to "share", "mimeType" to "text/plain", "text" to text)
        }
        val stream = extraStream(intent) ?: return null
        val path = copyToCache(context, stream) ?: return null
        return mapOf("type" to "share", "mimeType" to mimeType, "paths" to listOf(path))
    }

    private fun parseSendMultiple(context: Context, intent: Intent): Map<String, Any?>? {
        val mimeType = intent.type ?: return null
        val streams = extraStreams(intent) ?: return null
        val paths = streams.mapNotNull { copyToCache(context, it) }
        if (paths.isEmpty()) return null
        return mapOf("type" to "share", "mimeType" to mimeType, "paths" to paths)
    }

    @Suppress("DEPRECATION")
    private fun extraStream(intent: Intent): Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
        intent.getParcelableExtra(Intent.EXTRA_STREAM)
    }

    @Suppress("DEPRECATION")
    private fun extraStreams(intent: Intent): ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
        intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
    }

    private fun copyToCache(context: Context, uri: Uri): String? {
        return try {
            val resolver: ContentResolver = context.contentResolver
            val dir = File(context.cacheDir, "shared").apply { if (!exists()) mkdirs() }
            val outFile = File(dir, "shared_${System.currentTimeMillis()}")
            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output -> input.copyTo(output) }
            } ?: return null
            outFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }
}
