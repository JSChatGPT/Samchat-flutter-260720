package com.samafricaonline.samchat.contacts

import android.app.Service
import android.content.Intent
import android.os.IBinder

class ContactSyncService : Service() {
    override fun onBind(intent: Intent?): IBinder? = synchronized(lock) {
        adapter?.syncAdapterBinder
    }

    companion object {
        private val lock = Any()
        private var adapter: SamChatSyncAdapter? = null
    }

    override fun onCreate() {
        super.onCreate()
        synchronized(lock) {
            if (adapter == null) adapter = SamChatSyncAdapter(applicationContext, true)
        }
    }
}
