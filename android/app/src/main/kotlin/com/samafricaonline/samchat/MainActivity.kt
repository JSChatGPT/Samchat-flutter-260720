package com.samafricaonline.samchat

import android.content.Intent
import com.samafricaonline.samchat.contacts.ContactLinkPlugin
import com.samafricaonline.samchat.sms.SmsPlugin
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// local_auth's Android implementation requires a FragmentActivity host (it
// shows the BiometricPrompt via a DialogFragment) — plain FlutterActivity
// throws at runtime the first time authenticate() is called.
class MainActivity : FlutterFragmentActivity() {
    private lateinit var smsPlugin: SmsPlugin
    private lateinit var contactLinkPlugin: ContactLinkPlugin
    private var intentEventSink: EventChannel.EventSink? = null
    private var pendingIntentPayload: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        smsPlugin = SmsPlugin(messenger)
        smsPlugin.attachActivity(this)

        contactLinkPlugin = ContactLinkPlugin(messenger)
        contactLinkPlugin.attachActivity(this)

        pendingIntentPayload = IntentRouter.parse(this, intent)

        MethodChannel(messenger, "samchat/intent").setMethodCallHandler { call, result ->
            if (call.method == "consumeInitialIntent") {
                result.success(pendingIntentPayload)
                pendingIntentPayload = null
            } else {
                result.notImplemented()
            }
        }

        EventChannel(messenger, "samchat/intent/stream").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    intentEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    intentEventSink = null
                }
            },
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = IntentRouter.parse(this, intent) ?: return
        val sink = intentEventSink
        if (sink != null) sink.success(payload) else pendingIntentPayload = payload
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        smsPlugin.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        smsPlugin.detachActivity()
        contactLinkPlugin.detachActivity()
        super.onDestroy()
    }
}
