import 'package:flutter/services.dart';

/// Where an [AppIntent] should take the user.
enum AppIntentType { smsThread, smsCompose, share, openUserChat, answerCall }

/// A parsed Android Intent handed to us by MainActivity/IntentRouter.kt —
/// an SMS notification tap / `sms:`-scheme compose, a share-sheet
/// SEND/SEND_MULTIPLE from another app, a tap on the "connected apps" chip
/// on a contact's detail page (see OpenChatActivity.kt), or the incoming-call
/// notification's full-screen intent/Answer action (see SamChatConnection in
/// the samchat_telecom plugin).
class AppIntent {
  const AppIntent({
    required this.type,
    this.address,
    this.text,
    this.mimeType,
    this.paths,
    this.userId,
    this.callId,
    this.callerId,
    this.callerName,
    this.callerPhoto,
    this.isVideo,
    this.chatId,
  });

  final AppIntentType type;
  final String? address;
  final String? text;
  final String? mimeType;
  final List<String>? paths;
  final String? userId;

  // answerCall only:
  final String? callId;
  final String? callerId;
  final String? callerName;
  final String? callerPhoto;
  final bool? isVideo;
  final String? chatId;

  static AppIntent? fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    final type = switch (map['type']) {
      'sms_thread' => AppIntentType.smsThread,
      'sms_compose' => AppIntentType.smsCompose,
      'share' => AppIntentType.share,
      'open_user_chat' => AppIntentType.openUserChat,
      'answer_call' => AppIntentType.answerCall,
      _ => null,
    };
    if (type == null) return null;
    return AppIntent(
      type: type,
      address: map['address'] as String?,
      text: map['text'] as String?,
      mimeType: map['mimeType'] as String?,
      paths: (map['paths'] as List?)?.cast<String>(),
      userId: map['userId'] as String?,
      callId: map['callId'] as String?,
      callerId: map['callerId'] as String?,
      callerName: map['callerName'] as String?,
      callerPhoto: map['callerPhoto'] as String?,
      isVideo: map['isVideo'] as bool?,
      chatId: map['chatId'] as String?,
    );
  }
}

/// Bridges MainActivity's `samchat/intent` (initial launch intent, consumed
/// once) and `samchat/intent/stream` (subsequent intents while running)
/// channels.
class AppIntentChannel {
  static const _methodChannel = MethodChannel('samchat/intent');
  static const _eventChannel = EventChannel('samchat/intent/stream');

  static Future<AppIntent?> consumeInitialIntent() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('consumeInitialIntent');
    return AppIntent.fromMap(result);
  }

  static Stream<AppIntent> get stream => _eventChannel
      .receiveBroadcastStream()
      .map((event) => AppIntent.fromMap(event as Map<dynamic, dynamic>?))
      .where((intent) => intent != null)
      .cast<AppIntent>();
}
