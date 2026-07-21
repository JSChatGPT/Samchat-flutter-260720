package com.samafricaonline.samchat.contacts

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.ContactsContract.Data
import com.samafricaonline.samchat.MainActivity

/**
 * Invisible pass-through: the Contacts app fires ACTION_VIEW on our custom
 * Data row's content URI when the user taps the "SamChat" chip on a
 * contact's detail page (see contacts.xml + the intent-filter in the
 * manifest). We read back the SamChat user id we stashed in DATA3 and hand
 * off to MainActivity to open (or create) that direct chat.
 */
class OpenChatActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val userId = intent.data?.let { uri ->
            contentResolver.query(uri, arrayOf(Data.DATA3), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        }

        if (!userId.isNullOrEmpty()) {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    action = "com.samafricaonline.samchat.OPEN_USER_CHAT"
                    putExtra("userId", userId)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
            )
        }
        finish()
    }
}
