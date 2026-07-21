package com.samafricaonline.samchat.contacts

import android.accounts.Account
import android.content.AbstractThreadedSyncAdapter
import android.content.ContentProviderClient
import android.content.Context
import android.content.SyncResult
import android.os.Bundle

/**
 * No-op — we push contact rows directly from Dart right after
 * /contacts/sync succeeds (ContactLinkPlugin.kt), not on a periodic pull.
 * This class only needs to exist so the Contacts Provider treats our account
 * type as a legitimate sync-backed source.
 */
class SamChatSyncAdapter(context: Context, autoInitialize: Boolean) :
    AbstractThreadedSyncAdapter(context, autoInitialize) {
    override fun onPerformSync(
        account: Account?,
        extras: Bundle?,
        authority: String?,
        provider: ContentProviderClient?,
        syncResult: SyncResult?,
    ) {
        // Intentionally empty — see class doc.
    }
}
