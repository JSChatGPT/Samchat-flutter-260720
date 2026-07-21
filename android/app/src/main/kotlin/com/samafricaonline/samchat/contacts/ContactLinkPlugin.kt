package com.samafricaonline.samchat.contacts

import android.accounts.Account
import android.accounts.AccountManager
import android.app.Activity
import android.content.ContentProviderOperation
import android.content.ContentResolver
import android.content.Context
import android.provider.ContactsContract
import android.provider.ContactsContract.CommonDataKinds.Phone
import android.provider.ContactsContract.CommonDataKinds.StructuredName
import android.provider.ContactsContract.Data
import android.provider.ContactsContract.RawContacts
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Gives each SamChat friend a shadow RawContact under our own account type,
 * aggregated by Android into their existing device contact (matched by
 * phone number) — that's what makes a "SamChat" row show up under
 * "connected apps" on the contact's detail page. Tapping it fires
 * OpenChatActivity via the mimeType intent-filter in AndroidManifest.xml.
 */
class ContactLinkPlugin(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    companion object {
        const val ACCOUNT_TYPE = "com.samafricaonline.samchat"
        const val ACCOUNT_NAME = "SamChat"
        const val PROFILE_MIME_TYPE = "vnd.android.cursor.item/vnd.com.samafricaonline.samchat.profile"
    }

    private val methodChannel = MethodChannel(messenger, "samchat/contacts_link")
    private var activity: Activity? = null

    init {
        methodChannel.setMethodCallHandler(this)
    }

    fun attachActivity(activity: Activity) {
        this.activity = activity
    }

    fun detachActivity() {
        this.activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = activity?.applicationContext
        if (context == null) {
            result.error("NO_ACTIVITY", "Activity not attached", null)
            return
        }
        when (call.method) {
            "pushContacts" -> {
                @Suppress("UNCHECKED_CAST")
                val contacts = call.arguments as? List<Map<String, String>> ?: emptyList()
                pushContacts(context, contacts)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun ensureAccount(context: Context): Account {
        val account = Account(ACCOUNT_NAME, ACCOUNT_TYPE)
        val manager = AccountManager.get(context)
        if (!manager.accounts.contains(account)) {
            manager.addAccountExplicitly(account, null, null)
        }
        ContentResolver.setIsSyncable(account, ContactsContract.AUTHORITY, 1)
        ContentResolver.setSyncAutomatically(account, ContactsContract.AUTHORITY, false)
        return account
    }

    /** Each contact map has "userId", "phoneNumber", "displayName". */
    private fun pushContacts(context: Context, contacts: List<Map<String, String>>) {
        val account = ensureAccount(context)
        for (contact in contacts) {
            val userId = contact["userId"] ?: continue
            val phoneNumber = contact["phoneNumber"] ?: continue
            val displayName = contact["displayName"] ?: phoneNumber
            try {
                replaceRawContact(context, account, userId, phoneNumber, displayName)
            } catch (e: Exception) {
                // One bad row (e.g. a transient provider error) shouldn't stop the rest.
            }
        }
    }

    private fun replaceRawContact(
        context: Context,
        account: Account,
        userId: String,
        phoneNumber: String,
        displayName: String,
    ) {
        // Simplest correct upsert: drop whatever raw contact we previously made for
        // this user (cascades to its Data rows) and insert it fresh.
        context.contentResolver.delete(
            RawContacts.CONTENT_URI,
            "${RawContacts.ACCOUNT_TYPE} = ? AND ${RawContacts.ACCOUNT_NAME} = ? AND ${RawContacts.SYNC1} = ?",
            arrayOf(ACCOUNT_TYPE, ACCOUNT_NAME, userId),
        )

        val ops = ArrayList<ContentProviderOperation>()
        val rawContactIndex = ops.size
        ops.add(
            ContentProviderOperation.newInsert(RawContacts.CONTENT_URI)
                .withValue(RawContacts.ACCOUNT_TYPE, ACCOUNT_TYPE)
                .withValue(RawContacts.ACCOUNT_NAME, ACCOUNT_NAME)
                .withValue(RawContacts.SYNC1, userId)
                .build(),
        )
        ops.add(
            ContentProviderOperation.newInsert(Data.CONTENT_URI)
                .withValueBackReference(Data.RAW_CONTACT_ID, rawContactIndex)
                .withValue(Data.MIMETYPE, StructuredName.CONTENT_ITEM_TYPE)
                .withValue(StructuredName.DISPLAY_NAME, displayName)
                .build(),
        )
        ops.add(
            ContentProviderOperation.newInsert(Data.CONTENT_URI)
                .withValueBackReference(Data.RAW_CONTACT_ID, rawContactIndex)
                .withValue(Data.MIMETYPE, Phone.CONTENT_ITEM_TYPE)
                .withValue(Phone.NUMBER, phoneNumber)
                .withValue(Phone.TYPE, Phone.TYPE_OTHER)
                .build(),
        )
        ops.add(
            ContentProviderOperation.newInsert(Data.CONTENT_URI)
                .withValueBackReference(Data.RAW_CONTACT_ID, rawContactIndex)
                .withValue(Data.MIMETYPE, PROFILE_MIME_TYPE)
                .withValue(Data.DATA1, "Message on SamChat")
                .withValue(Data.DATA2, "SamChat")
                .withValue(Data.DATA3, userId)
                .build(),
        )
        context.contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
    }
}
