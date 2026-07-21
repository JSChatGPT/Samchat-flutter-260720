package com.samafricaonline.samchat.contacts

import android.app.Service
import android.content.Intent
import android.os.IBinder

class AuthenticatorService : Service() {
    private lateinit var authenticator: SamChatAuthenticator

    override fun onCreate() {
        super.onCreate()
        authenticator = SamChatAuthenticator(this)
    }

    override fun onBind(intent: Intent?): IBinder = authenticator.iBinder
}
