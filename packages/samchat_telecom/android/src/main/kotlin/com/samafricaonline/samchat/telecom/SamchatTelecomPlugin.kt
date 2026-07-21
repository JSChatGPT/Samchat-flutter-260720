package com.samafricaonline.samchat.telecom

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Dart-facing bridge for the native Telecom (self-managed ConnectionService)
 * incoming-call integration. A genuine FlutterPlugin (not a channel manually
 * wired inside MainActivity) specifically so it's registered via
 * GeneratedPluginRegistrant in *every* FlutterEngine — including the
 * headless one firebase_messaging spins up to run fcm_background_handler.dart
 * while the app is backgrounded or fully killed, which is exactly when this
 * is needed most.
 */
class SamchatTelecomPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "samchat/telecom")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "registerPhoneAccount" -> {
                SamChatConnectionService.registerPhoneAccount(appContext)
                result.success(null)
            }
            "reportIncomingCall" -> {
                val handled = SamChatConnectionService.reportIncomingCall(
                    appContext,
                    callId = call.argument<String>("callId") ?: "",
                    callerId = call.argument<String>("callerId"),
                    callerName = call.argument<String>("callerName") ?: "Someone",
                    callerPhoto = call.argument<String>("callerPhoto"),
                    isVideo = call.argument<Boolean>("isVideo") ?: false,
                    chatId = call.argument<String>("chatId"),
                )
                result.success(handled)
            }
            "syncAuthToken" -> {
                NativeAuthTokenStore.write(appContext, call.argument<String>("token"))
                result.success(null)
            }
            "syncApiBaseUrl" -> {
                val url = call.argument<String>("url")
                if (!url.isNullOrEmpty()) NativeAuthTokenStore.writeApiBaseUrl(appContext, url)
                result.success(null)
            }
            "endCall" -> {
                val callId = call.argument<String>("callId")
                if (callId != null) SamChatConnectionService.findConnection(callId)?.endFromApp()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
