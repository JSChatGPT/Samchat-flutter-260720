package com.samafricaonline.samchat.sms

import android.app.Activity
import android.app.role.RoleManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.Telephony
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener

/**
 * App-level (not pub.dev) platform channel backing the SMS feature: default-
 * SMS-app role request, reading the shared `content://sms` provider, and
 * sending. Instantiated once from MainActivity, which forwards
 * onActivityResult into it.
 */
class SmsPlugin(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityResultListener {

    companion object {
        private const val REQUEST_DEFAULT_SMS = 7421
    }

    private val methodChannel = MethodChannel(messenger, "samchat/sms")
    private val eventChannel = EventChannel(messenger, "samchat/sms/incoming")
    private var activity: Activity? = null
    private var pendingRoleResult: MethodChannel.Result? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    fun attachActivity(activity: Activity) {
        this.activity = activity
    }

    fun detachActivity() {
        this.activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        SmsDeliverReceiver.onMessage = { payload -> events?.success(payload) }
    }

    override fun onCancel(arguments: Any?) {
        SmsDeliverReceiver.onMessage = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = activity?.applicationContext
        if (context == null) {
            result.error("NO_ACTIVITY", "Activity not attached", null)
            return
        }
        when (call.method) {
            "isDefaultSmsApp" -> result.success(Telephony.Sms.getDefaultSmsPackage(context) == context.packageName)
            "requestDefaultSmsApp" -> requestDefault(result)
            "getConversations" -> result.success(getConversations(context))
            "getMessages" -> result.success(getMessages(context, call.argument<String>("threadId") ?: ""))
            "getOrCreateThreadId" -> {
                val address = call.argument<String>("address") ?: ""
                result.success(SmsSender.threadIdFor(context, address).toString())
            }
            "sendSms" -> {
                val address = call.argument<String>("address") ?: ""
                val body = call.argument<String>("body") ?: ""
                val id = SmsSender.send(context, address, body)
                result.success(mapOf("id" to id.toString(), "threadId" to SmsSender.threadIdFor(context, address).toString()))
            }
            "markThreadRead" -> {
                markThreadRead(context, call.argument<String>("threadId") ?: "")
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestDefault(result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not attached", null)
            return
        }
        pendingRoleResult = result
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            act.getSystemService(RoleManager::class.java).createRequestRoleIntent(RoleManager.ROLE_SMS)
        } else {
            Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
                .putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, act.packageName)
        }
        act.startActivityForResult(intent, REQUEST_DEFAULT_SMS)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_DEFAULT_SMS) return false
        val context = activity?.applicationContext
        val isDefault = context != null && Telephony.Sms.getDefaultSmsPackage(context) == context.packageName
        pendingRoleResult?.success(isDefault)
        pendingRoleResult = null
        return true
    }

    private fun getConversations(context: Context): List<Map<String, Any?>> {
        val projection = arrayOf(
            Telephony.Sms.THREAD_ID, Telephony.Sms.ADDRESS, Telephony.Sms.BODY,
            Telephony.Sms.DATE, Telephony.Sms.READ,
        )
        val cursor = context.contentResolver.query(
            Telephony.Sms.CONTENT_URI, projection, null, null, "${Telephony.Sms.DATE} DESC",
        ) ?: return emptyList()

        val byThread = LinkedHashMap<String, MutableMap<String, Any?>>()
        cursor.use {
            val idxThread = it.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)
            val idxAddress = it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val idxBody = it.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val idxDate = it.getColumnIndexOrThrow(Telephony.Sms.DATE)
            val idxRead = it.getColumnIndexOrThrow(Telephony.Sms.READ)
            while (it.moveToNext()) {
                val threadId = it.getString(idxThread) ?: continue
                val read = it.getInt(idxRead) == 1
                val existing = byThread[threadId]
                if (existing == null) {
                    byThread[threadId] = mutableMapOf(
                        "threadId" to threadId,
                        "address" to (it.getString(idxAddress) ?: ""),
                        "snippet" to (it.getString(idxBody) ?: ""),
                        "date" to it.getLong(idxDate),
                        "unreadCount" to if (read) 0 else 1,
                    )
                } else if (!read) {
                    existing["unreadCount"] = (existing["unreadCount"] as Int) + 1
                }
            }
        }

        return byThread.values.map { row ->
            row["displayName"] = resolveDisplayName(context, row["address"] as String)
            row
        }
    }

    private fun getMessages(context: Context, threadId: String): List<Map<String, Any?>> {
        val projection = arrayOf(Telephony.Sms._ID, Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE, Telephony.Sms.TYPE)
        val cursor = context.contentResolver.query(
            Telephony.Sms.CONTENT_URI, projection, "${Telephony.Sms.THREAD_ID} = ?", arrayOf(threadId),
            "${Telephony.Sms.DATE} ASC",
        ) ?: return emptyList()

        val result = mutableListOf<Map<String, Any?>>()
        cursor.use {
            val idxId = it.getColumnIndexOrThrow(Telephony.Sms._ID)
            val idxAddress = it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val idxBody = it.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val idxDate = it.getColumnIndexOrThrow(Telephony.Sms.DATE)
            val idxType = it.getColumnIndexOrThrow(Telephony.Sms.TYPE)
            while (it.moveToNext()) {
                result.add(
                    mapOf(
                        "id" to it.getString(idxId),
                        "address" to (it.getString(idxAddress) ?: ""),
                        "body" to (it.getString(idxBody) ?: ""),
                        "date" to it.getLong(idxDate),
                        "outgoing" to (it.getInt(idxType) == Telephony.Sms.MESSAGE_TYPE_SENT),
                    ),
                )
            }
        }
        return result
    }

    private fun markThreadRead(context: Context, threadId: String) {
        val values = ContentValues().apply { put(Telephony.Sms.READ, 1) }
        context.contentResolver.update(
            Telephony.Sms.CONTENT_URI, values,
            "${Telephony.Sms.THREAD_ID} = ? AND ${Telephony.Sms.READ} = 0", arrayOf(threadId),
        )
    }

    private fun resolveDisplayName(context: Context, address: String): String? {
        return try {
            val uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(address))
            context.contentResolver.query(
                uri, arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME), null, null, null,
            )?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        } catch (e: SecurityException) {
            null
        }
    }
}
